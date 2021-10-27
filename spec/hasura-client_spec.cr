require "./spec_helper"

Spec.before_suite do
  Hasura.connect ENV["HASURA_URL"], ENV["HASURA_ADMIN_SECRET"]
end

describe Hasura do
  it "stores the connection data for our Hasura GraphQL server" do
    Hasura.client.should_not be_nil
  end

  it "can query the stories in our DB via Hasura" do
    Hasura.query(GetStories)
    .story.map(&.title)
    .should contain("The Cloud")
  end

  it "generates a type system that matches the GraphQL schema" do
    #TODO: Make sure that a JSON response like this is parsed into the correct type:
    # <<-JSON
    # {
    #   "insert_message_one": {
    #   "id": "dbaa2172-0325-4b39-8ed1-4747710352ba",
    #   "created_at": "2021-10-20T23:34:14.919422+00:00"
    #   }
    # }
    # JSON
  end

  # --------------------------------------------------------------------------

end
