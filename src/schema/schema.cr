require "json"

# Auto-generated Crystal types that mirror the GraphQL schema as far as it is
# reflected in the parsed JSON dumpfile.
module Hasura::Schema
  {{ run __DIR__ + "/gen-types.cr" }}
end
