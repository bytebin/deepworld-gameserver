class Landmark < MongoModel
  fields [:player_id, :zone_id, :competition_id, :name, :votes, :votes_count]
  fields :position, Vector2
  fields :created_at, Time
end