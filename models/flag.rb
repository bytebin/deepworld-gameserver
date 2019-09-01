class Flag < MongoModel
  fields [:player_id, :zone_id, :position, :reason, :data]
  fields :created_at, Time
end