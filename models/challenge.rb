class Challenge < MongoModel
  fields [:creator_id, :name, :description, :xp, :zone_id]
  fields :position, Vector2
  fields :created_at, Time
end