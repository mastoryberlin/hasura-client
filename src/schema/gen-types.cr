require "ecr"
require "json"

schema = File.open __DIR__ + "/schema.json" do |schema_json|
  JSON.parse schema_json
end["__schema"]
schema_types = schema["types"].as_a

# :nodoc:
alias Scalar = String
# :nodoc:
alias NullableType = {Bool, GqlType}
# :nodoc:
alias NullableArrayOfNullableType = {Bool, Bool, GqlType}
# :nodoc:
alias GqlFieldType = Scalar | NullableType | NullableArrayOfNullableType

# :nodoc:
class GqlType
  property name
  property fields = {} of String => GqlFieldType
  def initialize(@name = "")
  end
  def to_s(io)
    io << @name
  end
end

response_types = [] of GqlType

STDERR.puts "__DIR__ points to #{__DIR__}"
graphql = Path.new __DIR__.gsub(/(\/lib\/hasura-client)?\/src\/schema\/?$/, "/graphql")
# graphql = Path.new "/home/felix/Mastory/c/c-the-cloud/graphql"
STDERR.puts "Generating types based on .gql files in path #{graphql}"
graphql_dir = Dir.open graphql
graphql_dir.each_child do |filename|
  STDERR.puts "\n= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =" +
    "\nParsing #{filename}" +
    "\n= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
  File.open graphql/filename do |user_defined_gql_operation|
    paren = 0
    brace = 0
    directive = false
    field = ""

    # initialize iterator variables with dummies to satisfy the compiler
    full_type = GqlType.new
    local_type = GqlType.new
    subfield = ""
    local_alias = ""

    nest = [] of {GqlType, GqlType, String, String} # a stack of info triples `{full_type, local_type, subfield, local_alias}`

    user_defined_gql_operation
    .each_char do |c|
      case c
      when '(' then paren += 1
      when ')' then paren -= 1
      when '{'
        if paren.zero?
          STDERR.puts "======> Encountered { -> starting new block"
          # entering new nesting level ->determine the type of the block, get its fields from the schema, store them in full_type,
          #                              then match every subsequently encountered field def against this full_type
          # 1) DETERMINE THE TYPE OF THE BLOCK
          #    a) Determine the location of this type definition in the schema
          fields_root_name = \
            if brace.zero?
              query_type, type_name = field.strip.split
              type_name = filename.sub(/\.g(?:raph)?ql$/, "") if type_name.blank?
              full_type.name = type_name
              local_type.name = type_name
              STDERR.puts "        top-level block - query_type=#{query_type}, type_name=#{type_name}"
              schema["#{query_type}Type"]["name"].as_s
            else
              has_alias = ':'.in? field
              if has_alias
              	local_alias, subfield = field.split(':').map &.strip
              else
              	subfield = field.strip
              	local_alias = subfield
              end
              field_type = full_type.fields[subfield] # here, full_type still refers to the OLD / parent / one nesting level above type
              type_name = case field_type
              when Scalar
                raise "Schema/GQL operation mismatch: encountered field '#{subfield}' with an opening brace, but schema says #{(nest.map &.first.name).join("/")} is a scalar"
              when NullableType                 then field_type[1].name
              when NullableArrayOfNullableType  then field_type[2].name
              end.not_nil!
              full_type = GqlType.new type_name
              local_type = GqlType.new local_alias
              STDERR.puts "        nested block (level #{brace}) - subfield=#{subfield}, local_alias=#{local_alias}, type_name=#{type_name}"
              type_name
            end

          # 2) GET ITS FIELDS FROM THE SCHEMA
          STDERR.puts "        Looking up #{fields_root_name} in GQL schema / __schema / types"
          fields_root = schema_types.find &.as_h["name"].as_s.==(fields_root_name)
          fields_in_schema = fields_root.not_nil!["fields"]
          fields_in_schema.as_a.each do |f|
            f = f.as_h
            field_name = f["name"].as_s
            modifiers = [] of String
            t = f["type"]
            while t["ofType"].as_h?
              modifiers << t["kind"].as_s
              t = t["ofType"]
            end

            kind = t["kind"].as_s
            name = t["name"].as_s
            full_type.fields[field_name] = case kind
            when "OBJECT"
              mod = modifiers.join("/")
              case mod
              when "NON_NULL/LIST/NON_NULL" then {false, false, GqlType.new name}
              when "NON_NULL/LIST"          then {false, true,  GqlType.new name}
              when "LIST/NON_NULL"          then {true,  false, GqlType.new name}
              when "LIST"                   then {true,  true,  GqlType.new name}
              when "NON_NULL"               then {false, GqlType.new name}
              when ""                       then {true,  GqlType.new name}
              else raise "Encountered an unknown sequence of type modifiers in GraphQL schema for field '#{field_name}' of '#{fields_root_name}': #{mod}"
              end
            when "SCALAR"
              base = case name.downcase
              when "boolean"          then "Bool"
              # when "float"            then "Float64"
              when "smallint", "int"  then "Int32"
              when "string", "uuid"   then "String"
              when "timestamptz"      then "Time"
              when "jsonb"            then "JSON::Any"
              else name + " (NOT TRANSLATED INTO CRYSTAL TYPE!)"
              end
              base += "?" unless modifiers.includes? "NON_NULL"
              base
            when "ENUM"
              "String" #TODO: Add enum type safety at a later point
            else raise "Unexpected kind of type for field '#{field_name}' of '#{fields_root_name}': #{kind}"
            end
          end

          STDERR.puts "        -> allowed fields are: #{full_type.fields.map{|k,v| "#{k} (#{crystalize v})"}.join(", ")}"
          nest << { full_type, local_type, subfield, local_alias }
          brace += 1
          # reset
          field = ""
          directive = false
        end # if paren.zero?
      when '}'
        if paren.zero?
          brace -= 1
          STDERR.puts "======> Encountered } -> adding type #{local_type} to response_types"
          if brace.zero?
            response_types << local_type
          else
            inner_full_type, inner_local_type, inner_subfield, inner_alias = nest.pop
            full_type, local_type, subfield, local_alias = nest.last
            STDERR.puts "        Popping nest - new full_type=#{full_type}, local_type=#{local_type}, subfield=#{subfield}, local_alias=#{local_alias}"
            ref = full_type.fields[inner_subfield]
            field_type = case ref
            in Scalar                       then ref
            in NullableType                 then {ref[0], inner_local_type}
            in NullableArrayOfNullableType  then {ref[0], ref[1], inner_local_type}
            end
            STDERR.puts "-----> Adding field #{inner_alias} (#{crystalize field_type}) to #{local_type}"
            local_type.fields[inner_alias] = field_type
          end
        end
      when '@'
        directive = true
      when '\n'
        if paren.zero? && !field.blank?
          has_alias = ':'.in? field
          if has_alias
            alias_name, field_name = field.split(':').map &.strip
          else
            field_name = field.strip
            alias_name = field_name
          end
          field_type = full_type.fields[field_name] # here, full_type still refers to the OLD / parent / one nesting level above type
          STDERR.puts "-----> Adding field #{alias_name} (#{crystalize field_type}) to #{local_type}"
          local_type.fields[alias_name] = field_type
          # reset
          field = ""
          directive = false
        end
      else
        field += c if paren.zero? && !directive
      end
    end
  end
end

STDOUT << <<-PREAMBLE
module Hasura::Schema
  class RequestError
    include JSON::Serializable
    class Extensions
      include JSON::Serializable
      property path : String
      property code : String
    end
    property extensions : Extensions
    property message : String
  end
PREAMBLE
STDOUT << '\n'
response_types.each do |gql_type|
  STDOUT << recursive_type_code(gql_type, 1) << '\n'
  lines = [] of String
  lines << "  class #{crystalize gql_type}Response"
  lines << "    include JSON::Serializable"
  lines << "    getter data : #{crystalize gql_type}?"
  lines << "    getter errors : Array(::Hasura::Schema::RequestError)?"
  lines << "  end\n"
  lines.each{|l| STDOUT << l << '\n'}
end
STDOUT.puts "end"

# --------------------------------------------------------------------------

def recursive_type_code(gql_type : GqlType, nesting_level = 0)
  String.build do |s|
    lines = [] of String
    lines << "class #{crystalize gql_type}"
    lines << "  include JSON::Serializable"

    gql_type.fields.each do |field_name, field_type|
      lines << "  property #{field_name} : #{crystalize field_type}"
    end

    lines.each do |l|
      s << "  " * nesting_level << l << '\n'
    end

    (gql_type.fields.values.reject &.is_a? Scalar)
    .each do |field_type|
      inner_gql_type = case field_type
      when NullableType                 then field_type[1]
      when NullableArrayOfNullableType  then field_type[2]
      end
      s << recursive_type_code(inner_gql_type.as(GqlType), nesting_level + 1)
    end

    s << "  " * nesting_level << "end\n"
  end
end

# --------------------------------------------------------------------------

def crystalize(v : GqlFieldType | GqlType)
  case v
  when GqlType then v.name.camelcase
  when Scalar then v
  when NullableType then v[1].to_s.camelcase + (v[0] ? "?" : "")
  when NullableArrayOfNullableType then "Array(" + v[2].to_s.camelcase + (v[1] ? "?" : "") + ")" + (v[0] ? "?" : "")
  end
end
