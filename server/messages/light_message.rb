# Type 0: sunlight, expects value to be an array of Y offsets at that x point
# TODO, kill 'y', it is not used
class LightMessage < BaseMessage
  configure collection: true
  data_fields :x, :y, :type, :value

  def self.message_for_indexes(zone, indexes)
    x_positions = indexes.map{ |i| [origin = Chunk.get_origin(zone, i).x, origin + zone.chunk_size.x - 1] }.flatten
    x_min = x_positions.min || 0
    x_max = [x_positions.max, zone.size.x].min

    LightMessage.new([[x_min, 0, 0, zone.light.sunlight[x_min..x_max]]])
  end

  def data_log
    nil
  end
end