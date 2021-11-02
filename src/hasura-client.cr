require "http/client"
require "json"

require "./schema"

# An auxiliary model to help with all kinds of queries and mutations to our DB.
module Hasura
  extend self

  # ==========================================================================
  # Nested classes
  # ==========================================================================

  class RequestError < Exception
    getter operation_name, code, path, hasura_message

    def initialize(@operation_name : String, @hasura_message : String, @code : String, @path : String)
      super "Hasura reported an error with #{operation_name}: #{hasura_message} ('#{code}' at #{path})"
    end
  end

  # ==========================================================================
  # Class properties
  # ==========================================================================

  class_getter! client : HTTP::Client,
                secret : String,
                endpoint : String

  # ==========================================================================
  # Methods
  # ==========================================================================

  def connect(host, secret, endpoint = ENV["HASURA_ENDPOINT"]? || "/v1/graphql")
    @@client = HTTP::Client.new host, 443, true
    @@secret = secret
    @@endpoint = endpoint
  end

  # --------------------------------------------------------------------------

  macro query(name, **variables)
    {% filename = __DIR__.gsub(/(\/lib\/hasura-client)?\/src\/?$/, "/graphql") + "/" + name.id.stringify + ".gql" %}
    {% raise "GraphQL file '#{name.id}.gql' not found in graphql folder (#{filename.id})" unless `[ -e "#{filename}" ]; echo -n $?` == "0" %}

    response = Hasura.post_request({
      query: {{ read_file filename }},
      operationName: {{ name.id.stringify }},
      variables: { {{ **variables }} } {% if variables.empty? %}of String => String{% end %}
    }.to_json) do |raw|
      Hasura::Schema::{{ name.id }}Response.from_json raw.body_io
    end
    response.data || begin
      err = response.errors.not_nil!.first
      raise Hasura::RequestError.new({{name.id.stringify}}, err.message, err.extensions.code, err.extensions.path)
    end
  end

  # --------------------------------------------------------------------------

  macro mutate(name, **variables)
    Hasura.query {{ name }}{% if !variables.empty? %}, {{ **variables }}{% end %}
  end

  # ==========================================================================
  # Helper methods
  # ==========================================================================

  def post_request(req, &block)
    client.post endpoint, HTTP::Headers{
      "content-type" => "application/json",
      "x-hasura-admin-secret" => secret
    }, req do |raw|
      yield raw
    end
  end

  # --------------------------------------------------------------------------

end
