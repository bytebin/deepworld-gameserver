# An entity is using an item
# status: 0 - select, 1 - start, -1 - stop
class EntityItemUseMessage < BaseMessage
  configure collection: true

  data_fields :entity_id, :inventory_type, :item_id, :status

  def data_log
    nil
  end
end
