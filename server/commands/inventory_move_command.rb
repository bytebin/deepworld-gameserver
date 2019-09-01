class InventoryMoveCommand < BaseCommand
  data_fields :item_id, :container, :position

  def execute
    player.inv.move(item_id, container, position)
  end

  def validate
    get_and_validate_item!
    @errors << "Item not in inventory" unless item_id == 0 || player.inv.contains?(item_id)
    @errors << "Can't move item" if @item['inventory type'] == 'hidden'
    @errors << "Invalid container '#{container}'" unless %w{i h s a}.include?(container)
    @errors << "Invalid position" unless position.is_a?(Fixnum)
  end

  def data_log
    nil
  end
end