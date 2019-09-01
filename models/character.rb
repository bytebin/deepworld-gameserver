class Character < MongoModel
  fields [:zone_id, :ilk, :name, :position, :metadata, :job, :stationary]
  fields :created_at, Time

  attr_accessor :entity

  def save!
    raise "No entity associated with character #{name}" unless @entity
    update attributes_hash.merge(position: @entity.position.to_a)
  end

end