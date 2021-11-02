require "./spec_helper"

Spec.before_suite do
  Hasura.connect ENV["HASURA_URL"], ENV["HASURA_ADMIN_SECRET"]
end

describe Hasura do
  it "stores the connection data for our Hasura GraphQL server" do
    Hasura.client.should_not be_nil
  end

  # --------------------------------------------------------------------------

  it "can query the stories in our DB via Hasura" do
    stories = Hasura.query(GetStories).story
    the_cloud = stories.find &.title.==("The Cloud")
    the_cloud.should_not be_nil
    if the_cloud
      the_cloud.id.should eq "5fddbaf0-bbbf-4394-b661-86f48d083ec9"
      the_cloud.created_at.month.should eq 9
      the_cloud.edit["shortcut"]["epic"].as_i.should eq 38
    end
  end

  # --------------------------------------------------------------------------

  it "can query a class in our DB via Hasura" do
    cls = Hasura.query(GetClass, id: "ca77e24c-76be-4ac1-851b-cf0c66fc17ca").class_by_pk
    cls.should_not be_nil
    if cls
      cls.name.should eq "Alpha Testers Class"
      cls.show_rover_app.should be_false
    end
  end

  # --------------------------------------------------------------------------

  it "can query a worksheet in our DB via Hasura" do
    worksheet = Hasura.query(GetWorksheet, id: "f1e12cd3-7968-4df3-8699-dfe3cf7f356b").geogebra_worksheet_by_pk
    worksheet.should_not be_nil
    if worksheet
      worksheet.number.should eq 4
    end
  end

  # --------------------------------------------------------------------------

  it "can query an episode in our DB via Hasura" do
    episode = Hasura.query(GetEpisode, id: "6dbea883-7663-4aa6-841d-2b65578f3cff").story_chapter_by_pk
    episode.should_not be_nil
    if episode
      episode.title.should eq "Greetings"
      episode.number.should eq 1
    end
  end

  # --------------------------------------------------------------------------

  it "can query a channel in our DB via Hasura" do
    channel = Hasura.query(GetChannel, id: "bec516e4-2056-471c-9e97-7ed8dafdda6c").channel_by_pk
    channel.should_not be_nil
    if channel
      channel.type.should eq "class"
    end
  end

  # --------------------------------------------------------------------------

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
