module Hasura::Schema
  extend self

  {% begin %}
  {{ run __DIR__ + "/gen-types.cr" }}
  {% end %}

end
