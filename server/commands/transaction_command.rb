# In-game currency transactions

class TransactionCommand < BaseCommand
  data_fields :key
  attr_accessor :item

  def execute
    # Create the transaction and add any inventory
    Transaction.create_transaction(player, key, -@item.cost) do
      add_inventory @item.inventory if @item.inventory
      add_zone @item.zone if @item.zone
      add_misc
      player.calculate_crowns_spent!
    end
  end

  def add_misc
    case @item['key']
    when /home\-world/
      player.queue_message EventMessage.new('uiHints', [])
      Scenarios::TutorialGiftHomeWorld.provision_world! player

    end

    if @item['premium'] == true
      player.convert_premium!
    end
  end

  def add_zone(zone_type)
    Configuration.where(key: 'world_version').first do |cfg|
      latest_version = cfg ? cfg.data.to_i : 19

      acquired_at = Time.now
      query_params = { gen_type: zone_type, active: false, version: latest_version, active_duration: nil }
      update_params = { active: true, owners: [player.id], private: true, acquired_at: acquired_at }
      Zone.update(query_params, update_params) do
        Zone.where(owners: [player.id], acquired_at: acquired_at).callbacks(false).first do |zone|
          if zone
            # Add zone to player owned zones list
            player.update({'$addToSet' => { owned_zones: zone.id }}, false)

            # Show player success dialog
            player.show_dialog [{ title: "World purchased!", text: "Your private world '#{zone.name}' is ready for exploration and adventure! Let's head there now." }, vip_status].compact, true do |values|
              unless values.any?{ |v| v =~ /cancel/i }
                player.send_to zone.id
              end
            end

          else
            Alert.create :private_world_unfulfillable, :critical, "Could not fulfill private #{zone_type} world for #{player.name} #{player.id}"
            player.show_dialog [{ 'text' => "We've started generating your private world. We'll let you know when it's ready for exploration!" }, vip_status].compact
          end
        end
      end
    end
  end

  def add_inventory(inventory_array)
    wardrobe_items = []

    notification = []
    inventory_array.each do |inventory_item|
      inventory_item = [*inventory_item]
      item = Game.item(inventory_item[0])
      quantity = inventory_item[1] || 1

      if item.wardrobe
        player.wardrobe << item.code unless player.wardrobe.include?(item.code)
        notification << { item: item.code, text: item.title }
        wardrobe_items << item.code
      else
        player.inv.add item.code, quantity, true, true
        notification << { item: item.code, text: "#{item.title} x #{quantity}" }
      end

      player.track_inventory_change :transaction, item.code, quantity
    end

    player.inv.save!
    if wardrobe_items.present?
      player.save!
      player.queue_message WardrobeMessage.new(wardrobe_items)
    end

    if notification.present?
      if player.v3?
        player.show_dialog({ title: 'You received:', sections: [{ list: notification }, vip_status].compact, replace: 'shop_drawer' })
      else
        player.notify({ sections: [{ title: 'You received:', list: notification }, vip_status].compact }, 12)
      end
    end
  end

  def vip_status
    if !player.windows? && player.crowns_spent
      current_vip_tier_index = vip_status_tier_index(player.crowns_spent)
      current_vip_tier = vip_status_tiers[current_vip_tier_index]
      if next_vip_tier = vip_status_tiers[current_vip_tier_index + 1]
        new_crowns_spent = player.crowns_spent + @item.cost
        if new_crowns_spent < next_vip_tier.requirements.crowns_spent
          gap = next_vip_tier.requirements.crowns_spent - current_vip_tier.requirements.crowns_spent
          gap_progress = new_crowns_spent - current_vip_tier.requirements.crowns_spent
          gap_diff = gap - gap_progress
          progress = (gap_progress / gap.to_f * 100).floor
          tier_name = %w{None Iron Brass Sapphire Ruby Onyx}[current_vip_tier_index + 1]
          tier_next_text = current_vip_tier_index > 0 ? 'next' : 'first'
          {
            'text' => "\nYou are #{progress}% of the way to the #{tier_next_text} VIP tier! Spend #{gap_diff} more crown#{'s' if gap_diff != 1} to rank as #{tier_name} in the Order of the Moon and get XP bonuses and other new benefits!",
            'text-scale' => 0.6,
            'text-color' => '999999'
          }
        else
          {
            'text' => "\nYou have achieved a new VIP tier!",
            'text-size' => 0.6,
            'text-color' => '999999'
          }
        end
      end
    end
  end

  def vip_status_tier_index(crowns)
    (vip_status_tiers.index{ |tier| crowns < tier.requirements.crowns_spent } || vip_status_tiers.size) - 1
  end

  def vip_status_tiers
    [Hashie::Mash.new(requirements: { crowns_spent: 0 })] + Game.config.orders['Order of the Moon'].tiers
  end

  def validate
    if @item = Transaction.item(key)

      if player.crowns < @item.cost
        @errors << "You don't have enough crowns to buy that!"
        player.flag! 'reason' => "attemped purchase without enough crowns", 'data' => { 'key' => key }
      end

      # Prohibited inventory disallows transaction based on player's current inventory
      if @item.prohibit_inventory
        @item.prohibit_inventory.each do |inv|
          item = Game.item(inv)
          if player.inv.contains?(item.code)
            @errors << "You already have a #{item.title.downcase} and cannot buy this item."
            break
          end
        end
      end

      # Prohibit all purchases in tutorial
      if player.zone.tutorial? && !@item.tutorial
        @errors << "You cannot purchase that item in the tutorial."
      end
    else
      @errors << "#{key} is not a purchasable item."
    end
  end

  def fail
    alert @errors.first || "Unknown error."
    player.queue_message StatMessage.new(['crowns', player.crowns])
  end

end