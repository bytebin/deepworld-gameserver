class Prefab < MongoModel
  fields [:name, :creator_id, :blocks, :size, :active, :tags]
  fields :created_at, Time

end