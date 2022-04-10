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
    c = HTTP::Client.new host, 443, true
    c.compress = false
    @@client = c
    @@secret = secret
    @@endpoint = endpoint
  end

  # --------------------------------------------------------------------------

  macro query(gql_name, **variables)
    {% filename = __DIR__.gsub(/(\/lib\/hasura-client)?\/src\/?$/, "/graphql") + "/" + gql_name.id.stringify + ".gql" %}
    {% raise "GraphQL file '#{gql_name.id}.gql' not found in graphql folder (#{filename.id})" unless `[ -e "#{filename}" ]; echo -n $?` == "0" %}
    begin
      %response = Hasura.post_request({
        query: {{ read_file filename }},
        operationName: {{ gql_name.id.stringify }},
        variables: { {{ **variables }} } {% if variables.empty? %}of String => String{% end %}
      }.to_json)
      %r = Hasura::Schema::{{ gql_name.id }}Response.from_json %response.body
      if %errs = %r.errors
        %err = %errs.first
        raise Hasura::RequestError.new({{gql_name.id.stringify}}, %err.message, %err.extensions.code, %err.extensions.path)
      end
      %r.data.not_nil!
    end
  end

  # --------------------------------------------------------------------------

  macro mutate(gql_name, **variables)
    Hasura.query({{ gql_name }}{% if !variables.empty? %}, {{ **variables }}{% end %})
  end

  # ==========================================================================
  # Helper methods
  # ==========================================================================

  def post_request(request)
    client.post(endpoint, HTTP::Headers{
      "Accept" => "application/json",
      "Accept-Encoding" => "identity",
      "X-Hasura-Admin-Secret" => secret
    }, request)
  end

  # --------------------------------------------------------------------------

end
