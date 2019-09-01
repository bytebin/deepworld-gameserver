class GiveCommand < BaseCommand
  data_fields :recipient_name, :item_id, :quantity

  def execute
    # Deduct from player's inventory unless admin
    player.inv.remove(item_id, quantity, true) unless admin?
    notify "You gave #{@quantity} #{@item_title_pluralized} to #{@recipient_name}", 11 unless player == @recipient

    # Add to recipient's inventory
    if @quantity > 0
      @recipient.inv.add item_id, quantity, true
      @recipient.alert "You received #{@quantity} #{@item_title_pluralized} from #{player.name}"
    else
      @recipient.inv.remove item_id, -quantity, true
      @recipient.alert "#{-@quantity} #{@item_title_pluralized} was removed from your inventory."
    end

    # Track changes
    player.track_inventory_change :give, item_id, -quantity, nil, @recipient
    @recipient.track_inventory_change :receive, item_id, quantity, nil, player
  end

  def validate
    get_and_validate_item!

    @errors << "Invalid quantity" unless @quantity.is_a?(Fixnum) && (admin? || @quantity > 0)

    if @errors.blank?
      @recipient = zone.find_player(@recipient_name)
      @item_title_pluralized = @quantity > 1 ? @item.title.downcase + 's' : @item.title.downcase
      @errors << "Can not find player #{recipient_name}" unless @recipient
      @errors << "Can not give to yourself" if @recipient == player && !admin?

      unless admin?
        if @item.tradeable == false
          @errors << "Can not give item"
          player.alert "Cannot trade #{@item.title.downcase}."
        end
        if @item.place_entity && !player.can_place_entity?(@item)
          @errors << "Not enough inventory to give servant"
          player.alert "Cannot give servant while active."
        end
      end
    end

    if @errors.blank? && !admin?
      @errors << "Sorry, you don't have that many #{@item_title_pluralized} in your inventory." unless player.inv.quantity(item_id) >= @quantity
    end
  end

  def fail
    alert @errors.first
    player.inv.send_message item_id
  end
end