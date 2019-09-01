class Chat < MongoModel
  fields [:message, :player_id, :zone_id, :muted]
  fields :created_at, Time
end