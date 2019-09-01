# Zone block has changed
class BlockChangeMessage < BaseMessage
  configure collection: true
  data_fields :x, :y, :layer, :entity_id, :item_id, :mod

  def data_log
    nil
  end
end