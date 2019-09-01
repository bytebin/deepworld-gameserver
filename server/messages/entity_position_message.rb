# The location and velocity of an entity
class EntityPositionMessage < BaseMessage
  configure collection: true

  data_fields :entity_id, :x, :y, :velocity_x, :velocity_y, :direction, :target_x, :target_y, :animation

  def data_log
    nil
  end
end