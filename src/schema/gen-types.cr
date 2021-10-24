require "ecr"

class GqlType
  property name
  property fields = {} of String => String | GqlType
  def initialize(@name = "")
  end
  def to_s(io)
    io << @name
  end
end

response_types = [] of GqlType

graphql = Path.new __DIR__.gsub(/(\/lib\/hasura-client)?\/src\/schema\/?$/, "/graphql")
graphql_dir = Dir.open graphql
graphql_dir.each_child do |filename|
  File.open graphql/filename do |gql|
    response_type = GqlType.new

    paren = 0
    brace = 0
    field = ""

    local_types = [] of GqlType

    gql.each_char do |c|
      case c
      when '('
        paren += 1
      when ')'
        paren -= 1
      when '{'
        if paren.zero?
          if brace.zero?
            type_name = field.strip.sub(/^\s*\b(?:query|mutation|subscription)\b\s*/, "")
            type_name = filename.sub(/\.g(?:raph)?ql$/, "") if type_name.blank?
            response_type.name = type_name
            local_types << response_type
          else
            t = GqlType.new field.strip.camelcase
            cur = local_types.last
            cur.fields[field.strip] = t
            local_types << t
          end
          brace += 1
          field = ""
        end
      when '}'
        if paren.zero?
          brace -= 1
          local_types.pop
          response_types << response_type if brace.zero?
        end
      when '\n'
        if paren.zero? && !field.strip.blank?
          cur = local_types.last? || response_type
          cur.fields[field.strip] = "Type"
          field = ""
        end
      else
        field += c if paren.zero?
      end
    end
  end
end

response_types.each do |gql_type|
  puts recursive_type_code(gql_type)
end

def recursive_type_code(gql_type : GqlType, nesting_level = 0)
  String.build do |s|
    lines = [] of String
    lines << "class #{gql_type.name}"
    lines << "  include JSON::Serializable"
    gql_type.fields.each do |field_name, field_type|
      lines << "  property #{field_name} : #{field_type}"
    end

    lines.each do |l|
      s << "  " * nesting_level << l << '\n'
    end

    (gql_type.fields.values.select &.is_a? GqlType)
    .each do |field_type|
      s << recursive_type_code(field_type.as(GqlType), nesting_level + 1)
    end

    s << "  " * nesting_level << "end\n"
  end
end

# --------------------------------------------------------------------------
