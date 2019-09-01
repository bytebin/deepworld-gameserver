class InventoryUseCommand < BaseCommand
  # Inventory_type: 0 - main, 1 - secondary
  # Status: 0 - select, 1 - start, 2 - end
  data_fields :inventory_type, :item_id, :status, :details

  def execute
    # Consumables have arbitrary effects
    if @item.category == 'consumables'
      if status == 1
        player.consume @item, details
      end

    # Misc items
    elsif @item.action == 'teleport'
      player.teleport! details, true, 'teleport'

    # Everything else (tools, prosthetics)
    else
      # Tool (primary inventory, visible to other players)
      if inventory_type == 0
        player.current_item = item_id unless status == 2
      end

      # Queue use messages for primary inventory (tool)
      queue_tracked_peer_messages EntityItemUseMessage.new([[player.entity_id, inventory_type, item_id, status]]) # TODO: Only queue if ID & status changed (target may change but we don't need to send more messages then)

      # If a damaging item
      if @item.damage
        # Add new attacks if status change
        if status == 1 and details.present? # Details = target entity IDs
          [*details].first(player.max_targetable_entities).each do |t|
            if entity = zone.entities[t]
              player.attack entity, @item, inventory_type
            end
          end
        end
      end
    end

    player.last_used_inventory_at = Time.now
    player.zone.player_event player, :inventory_use, @item
  end

  def validate
    get_and_validate_item!

    # Validate the status
    @errors << "Invalid status code #{status}" unless (status >= 0 && status <= 2)

    # Only validate item if not a zero item
    if @item && @item.code > 0
      # Make sure the player has the used item
      @errors << "Player doesn't have any #{item_id}" unless player.inv.contains?(item_id)

      # Make sure it's a tool/consumable
      @errors << "#{item_id} is not usable" unless %w{tools shields consumables prosthetics accessories}.include?(@item.category)

      # Don't allow shooting if suppressed
      if @item.action == 'gun' && player.suppress_guns? && status > 0
        @errors << "Suppressed"
      end

      # Make sure inventory type is valid
      if @item['inventory type']
        @errors << "Wrong inventory type" unless @inventory_type == 1
      end

      # Validate action for start status
      if (status == 1)
        # Action validation
        case @item.action
        when 'heal'
          #@errors << 'Health is already full' if player.health == player.max_health TODO: Reinstate after client 1.9.10
        end
      end
    end

    # Targets should not include players (YET)
    @errors << "Cannot attack other players" if @item.damage && [*details].any?{ |t| zone.entities[t].is_a?(Player) }
  end

  def fail
    player.inv.send_message item_id if @item && %w{consumables accessories}.include?(@item.category)
  end

  def data_log
    nil
  end
end
