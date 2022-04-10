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

  it "can create a new channel in our DB via Hasura" do
    chatroom = Hasura.mutate(AddChatroom, name: "Test Channel X", type: "class", class_id: "252393c9-10e5-478a-b9f9-157f0bfb5fb7").insert_channel_one
    chatroom.should_not be_nil
    if chatroom
      channel = Hasura.query(GetChannel, id: chatroom.id).channel_by_pk
      channel.should_not be_nil
      if channel
        channel.name.should eq "Test Channel X"
      end
    end
  end

  # --------------------------------------------------------------------------

  it "can run several mutations in a chain, where the success of one is necessary for the next", focus: true do
    chatroom = Hasura.mutate(AddChatroom, name: "Test Channel X", type: "class", class_id: "a2f511e2-7d3e-4ba3-9f17-4f726ac3850d").insert_channel_one
    chatroom.should_not be_nil
    if chatroom
      members = [
        {channel_id: chatroom.id, character_id: "New Nick"},
        {channel_id: chatroom.id, character_id: "New VZ"},
        {channel_id: chatroom.id, student_id: "359ada32-44e9-44bd-9c2a-3a7404cf7b27"},
      ]
      Hasura.mutate(AddChatroomMembers, members: members)
      channel = Hasura.query(GetChannel, id: chatroom.id).channel_by_pk
      channel.should_not be_nil
      if channel
        channel.name.should eq "Test Channel X"
      end
    end
  end

end
