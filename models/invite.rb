class Invite < MongoModel
  fields [:player_id, :player_name, :invitee_fb_id, :created_at, :linked, :responded]
end