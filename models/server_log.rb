class ServerLog < MongoModel
  fields [:created_at, :zone_id, :server_id, :type, :data]
end