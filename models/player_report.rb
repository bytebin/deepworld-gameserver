class PlayerReport < MongoModel
  fields [:reportee_id, :reporter_id, :zone_id, :chats]
  fields :created_at, Time

end