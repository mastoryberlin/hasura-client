require "http/client"
require "json"

require "./schema"

# An auxiliary model to help with all kinds of queries and mutations to our DB.
module Hasura
  extend self

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
    Hasura.post_request({
      query: {{ read_file filename }},
      operationName: {{ name.id.stringify }},
      variables: { {{ **variables }} } {% if variables.empty? %}of String => String{% end %}
    }.to_json)
  end

  # --------------------------------------------------------------------------

  macro mutate(name, **variables)
    Hasura.query {{ name }}{% if !variables.empty? %}, {{ **variables }}{% end %}
  end

  # ==========================================================================
  # Helper methods
  # ==========================================================================

  def post_request(req)
    puts req.to_s
  end

  # --------------------------------------------------------------------------

end
