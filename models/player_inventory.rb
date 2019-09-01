class PlayerInventory
  ACCESSORY_SLOTS = 20
  ACCESSORY_EXPANDER_ITEM_CODE = 1129
  HOTBAR_SLOTS = 10

  attr_accessor :locations

  def items
    @inventory
  end

  def initialize(player)
    @changes = {}
    @changes_lock = Mutex.new

    @player = player
    migrate_inventory!

    @inventory = player.inventory || {}
    @locations = player.inventory_locations

    # Preperations
    refresh_accessories!
    delete_nonexistant_items!
  end

  def contains?(item_id, count = 1)
    count <= 0 || self.quantity(item_id) >= count
  end

  def quantity(item_id)
    @inventory[item_id.to_s] || 0
  end

  def add(item_id, count = 1, send_message = false, force = false)
    item = Game.item(item_id.to_i)

    raise "Item '#{item_id}' not found in game configuration!" if item.nil? || item_id.nil?

    item_id = item_id.to_s

    if @player.zone.try(:static) && !@player.admin && !force
      count = @player.zone.static_zone.inventory_allowed(@player, item_id, count)
      return if count == 0
    end

    @inventory[item_id] = quantity(item_id) + count
    @changes_lock.synchronize { @changes[item_id] = (@changes[item_id] || 0) + count }

    # Inventory features
    if item.appearance
      @player.change item.appearance => item.code
    end

    if item.supercede_inventory
      item.supercede_inventory.each do |i|
        superceded = Game.item(i).code
        remove(superceded, self.quantity(superceded), true) if self.contains?(superceded)
      end
    end

    send_message item_id if send_message
    refresh_accessories!
  end

  def add_from_block(item, mod, send_message = false)
    # Add to player's inventory (use decay or alternate inventory if specified by the item config)
    is_decayed = (item.mod == 'decay' and mod > 0)
    is_mod_inventory = item.mod_inventory && mod >= item.mod_inventory[0]

    inventory_item_name = (is_decayed ? item['decay inventory'] : nil) ||
      (is_mod_inventory ? item.mod_inventory[1] : nil) ||
      item.inventory
    inventory_item_code = inventory_item_name.nil? ? item.code : Game.item_code(inventory_item_name)
    quantity = item.mod == 'stack' && mod > 0 ? mod : 1

    add inventory_item_code, quantity, send_message unless inventory_item_code.nil?

    # HACK: Remove once mod_inventory works in client
    add item.code, 1, true if item.code == 916 && mod == 0
  end

  def add_with_message(item, count = 1, message = 'You received:')
    add item.code, count, true
    notification = [{ item: item.id, text: "#{item.title} x #{count}" }]
    @player.notify({ sections: [{ title: message, list: notification }] }, 12)
  end

  def gift_items!(items_and_quantities)
    msg = []
    items_and_quantities.each_pair do |item_name, qty|
      if item = Game.item(item_name)
        add item.code, qty, true
        msg << "#{item.title} x #{qty}"
      end
    end

    @player.alert_profile "You received:", msg.join(', ')
  end

  def remove(item_id, count = 1, send_message = false)
    item_id = item_id.to_s

    item_count = quantity(item_id) - count

    if item_count <= 0
      @inventory.delete item_id
      remove_from_containers item_id
    else
      @inventory[item_id] = item_count
    end

    @changes_lock.synchronize { @changes[item_id] = (@changes[item_id] || 0) - count }

    send_message item_id if send_message
    refresh_accessories!
  end

  def move(item_id, container, position = 0)
    return unless self.contains? item_id

    item_id = item_id.to_i

    # Return if position is unchanged
    return if location_of(item_id) == [container, position]

    remove_from_containers item_id

    # No location change for inventory
    if container != 'i'
      # Move
      @locations[container][position] = item_id.to_i
    end

    refresh_accessories!
  end

  def accessories
    return @accessories if @accessories

    # Accessory container and hidden items
    acc = (@locations['a'] || [])[0..max_accessories-1].compact
    @accessories = acc.select{ |item| self.contains? item }.map{|i| Game.item(i.to_i) } + hidden

    @accessories
  end

  def accessory_with_use(use)
    accessories.find{ |a| a.use[use] }
  end

  def max_accessories
    5 + @player.skill('stamina') + (contains?(ACCESSORY_EXPANDER_ITEM_CODE) ? 5 : 0)
  end

  def hidden
    @hidden ||= Game.config.hidden_items.select{ |i| self.contains? i }.map{|i| Game.item(i.to_i)}
  end

  def bonus
    @bonus ||= accessories.select{ |a| a.use['skill bonus'] }
  end

  def regeneration
    @regeneration ||= bonus.map{ |a| a.bonus.regen }.compact.max
  end

  def send_message(item_ids = nil)
    @player.queue_message InventoryMessage.new(self.to_h(item_ids))
  end

  def save!
    updates = {'$set' => {inventory_locations: @locations}}
    chg = {}

    @changes_lock.synchronize do
      chg = @changes.dup
      @changes.clear
    end

    unless chg.empty?
      updates['$inc'] = chg.inject({}){ |hash, (k,v)| hash["inventory.#{k}"] = v; hash}
    end

    @player.update(updates, false) do
      yield if block_given?
    end
  end

  def to_h(item_ids = nil)
    item_ids = item_ids ? [item_ids].flatten.map(&:to_s) : @inventory.keys

    # Filter items
    item_ids.inject({}) do |hash, item|
      hash[item] = [@inventory[item] || 0] + location_of(item)
      hash
    end
  end

  def location_of(item_id)
    item_id = item_id.to_i

    @locations.each do |con, values|
      loc = values.index(item_id)
      return [con, loc] if loc
    end

    if loc = Game.config.hidden_items.index(item_id)
      return ['z', loc]
    else
      return @player.v3? ? [] : ['i', -1]
    end
  end

  private

  def delete_nonexistant_items!
    # Clean inventory
    @inventory.keys.each do |key|
      unless Game.item_exists?(key.to_i)
        @inventory.delete key
      end
    end

    # Clean hotbars
    @locations.each do |container, values|
      @locations[container] = values.map do |i|
        Game.item_exists?(i) ? i : nil
      end
    end
  end

  def remove_from_containers(item_id)
    item = item_id.to_i

    # Update containers to remove item
    @locations.each do |con, values|
      loc = values.index(item)
      values[loc] = nil if loc
    end
  end

  def refresh_accessories!
    @hidden = nil
    @accessories = nil
    @regeneration = nil
    @bonus = nil
  end

  def migrate_inventory!
    if @player.inventory_locations.nil?
      previous = (@player.inventory || {}).dup

      # Inventory and location defaults
      @player.inventory_locations = { 'a' => [nil] * ACCESSORY_SLOTS, 'h' => [nil] * HOTBAR_SLOTS }
      @player.inventory = {}

      previous.dup.each do |k, v|
        item = k.to_s

        v = [v].flatten
        quantity = v[0].to_i
        location = v[1].to_s
        index = v[2].to_i

        # Quantity
        @player.inventory[item] = quantity

        # Location
        if ['a','h'].include? location
          @player.inventory_locations[location][index] = item.to_i
        end
      end

      # persist to the database
      @player.update(
        inventory: @player.inventory,
        inventory_locations: @player.inventory_locations)
    end
  end
end
