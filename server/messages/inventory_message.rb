# Inventory update for a player
class InventoryMessage < BaseMessage
  data_fields :inventory_hash

  def data_log
    nil
  end
end

