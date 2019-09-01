class BlockPlaceCommand < BaseCommand
  data_fields :x, :y, :layer, :item_id, :item_mod
  attr_accessor :item
  attr_accessor :surrogate

  def execute
    item_id = @item_id.to_s

    # Decrement item count or remove from inventory
    player.inv.remove(item_id, 1, @surrogate) unless @item.place_entity

    # Decrement any additional cost items from inventory
    if @item.placing_cost
      @item.placing_cost.each_pair do |cost_item_name, cost_qty|
        cost_item = Game.item(cost_item_name)
        player.inv.remove cost_item.code, cost_qty, true
        player.emote "-#{cost_qty} #{cost_item.title}"
      end
    end

    # Update the block
    unless zone.static && !player.active_admin?
      # Look for a minigame on the item
      check_minigame

      mod = layer == LIQUID ? LIQUID_LEVELS : @item_mod
      zone.update_block(@surrogate ? nil : player.entity_id, @x, @y, @layer, @item_id, mod, player, @meta) unless @item.place_entity

      # Spawn block entity if item requries it
      zone.spawner.spawn_block_entity Vector2[@x, @y], @item.id if @item.entity

      # Spawn place entity
      if @item.place_entity
        if entity = zone.spawn_entity(@item.place_entity, @x, @y, nil, true)
          player.own_entity! entity
          player.send_hint @item.hint[1..-1] if @item.hint
        end
      end

      # Increment totals
      zone.items_placed += 1
      player.place_item(@item, Vector2[@x, @y])

      # Queueing
      if timer = place_timer(@item)
        if !@item.timer_requirement || player.send(@item.timer_requirement + "?", Vector2[@x, @y])
          zone.add_block_timer Vector2[@x, @y], timer[0], timer[1], player
        end
      end

      # Transform
      if @item.place_transform
        @item.place_transform.each_pair do |key, value|
          transform_item = Game.item(key)
          if transform_item.layer_code && zone.peek(@x, @y, transform_item.layer_code)[0] == transform_item.code
            if result_item = Game.item(value)
              zone.update_block nil, @x, @y, result_item.layer_code, result_item.code
            end
          end
        end
      end

      # Place use
      if @item['use'] && @item['use']['place']
        player.command! BlockUseCommand, [@x, @y, FRONT, []]
      end

      # Place hint
      player.send_hint @item.place_hint if @item.place_hint

      # Custom processing
      custom_place if @item.custom_place
    end
  end

  def place_timer(item)
    # Basic timer
    if item.timer
      [item.timer_delay, item.timer]

    # Adjacency changes
    elsif change = item.adjacent_change
      should_change = false

      direction = change[0]
      position = Vector2[@x, @y] + Vector2[direction[0], direction[1]]
      operator = change[1]

      if zone.in_bounds?(position.x, position.y)
        use = change[2]
        item = Game.item(zone.peek(position.x, position.y, FRONT)[0])
        should_change = case operator
          when '=' then item.use[use]
          when '!' then !item.use[use]
          else false
        end

      # If not in bounds and operator is NOT, change (since out of bounds definitely is NOT the required item)
      elsif operator == '!'
        should_change = true

      end

      if should_change
        change_item_code = Game.item(change[3]).code
        [change[4] || 0, ['front item', change_item_code]]
      else
        nil
      end
    end
  end

  def check_minigame
    # Create minigame if item requires it
    if @item.minigame && @item.minigame.start == 'place' && !@item.minigame.static
      if minigame = zone.start_minigame(:deathmatch, Vector2[@x, @y], player)
        @meta = minigame.meta
      end
    end
  end

  def custom_place
    case @item.id
    # Maw plugging
    when 'building/plug'
      base = zone.peek(@x, @y, BASE)[0]
      if [5, 6].include?(base)
        zone.update_block(nil, @x, @y, BASE, base + 2)
        zone.update_block(nil, @x, @y, FRONT, 0)
        unless zone.biome == 'deep' && zone.acidity > 0.01
          Achievements::SpawnerStoppageAchievement.new.check(player, 'maw')
          player.add_xp :plug
        end
      end
    when /protector-enemy/
      zone.get_meta_block(@x, @y).data['!'] = [201, 200]
    when /plenty/
      meta = zone.get_meta_block(@x, @y)
      meta.data['y'] = (Time.now - Time.new(2012, 12, 20)).to_i
      meta.data['$'] = '?'
    when /snowball$/
      # if @x < zone.size.x-1 && zone.peek(@x+1, @y, FRONT)[0] == @item.code
      #   if @y > 0 && zone.peek(@x+1, @y-1, FRONT)[0] == @item.code && zone.peek(@x, @y+1, FRONT)[0] == Game.item_code('arctic/snowball-medium')
      #     zone.update
      #   zone.update_block nil, @x, @y, FRONT, Game.item_code('arctic/snowball-medium')
      #   zone.update_block nil, @x+1, @y, FRONT, 0
    when 'signs/guild'
      if player.guild
        player.guild.set_location(zone.id, x, y) do
          zone.set_meta_block @x, @y, @item, player, player.guild.construct_metadata
        end
      else
        Guild.create(zone_id: zone.id, position: [@x, @y]) do |guild|
          guild.set_leader(player)
          zone.set_meta_block @x, @y, @item, player, player.guild.construct_metadata
        end
      end
    end
  end

  def validate
    run_if_valid :get_and_validate_item!
    run_if_valid :validate_layer unless active_admin?
    run_if_valid :validate_biome
    run_if_valid :validate_placeable
    run_if_valid :validate_placeover unless @layer == BASE
    run_if_valid :validate_inventory
    run_if_valid :validate_skill
    run_if_valid :validate_mod
    run_if_valid :validate_karma_allowed
    run_if_valid :validate_guild
    run_if_valid :validate_ownership unless active_admin?
    run_if_valid :validate_membership unless active_admin?
    run_if_valid :validate_protected unless active_admin?
    run_if_valid :validate_field unless active_admin?
    run_if_valid :validate_reach unless active_admin? || surrogate
    run_if_valid :validate_spacing unless active_admin?
    run_if_valid :validate_constraints unless active_admin?
    run_if_valid :validate_zone_limits unless active_admin?
    run_if_valid :validate_spawn_cover
    run_if_valid :validate_role unless admin?

    #run_if_valid :validate_place_over_entity
    run_if_valid :validate_place_entity
  end

  def fail
    p "[BlockPlaceCommand] Couldn't place: #{@errors}" if Deepworld::Env.development?

    EM.add_timer(0.25) do
      # If any errors are not blank, send block message back to client so its state is consistent
      queue_message BlockChangeMessage.new(@x, @y, @layer, nil, peek[0], peek[1])
      player.inv.send_message item_id
    end
  end

  private

  #################
  # Validations
  #################

  # Ensure the layer is legitimate
  def validate_layer
    @errors << "Layer #{layer} invalid" unless (layer > BASE && layer < LIGHT)
  end

  # Ensure we can place this block in this biome
  def validate_biome
    @errors << "Can only place in #{@item.biome}" if @item.biome && @item.biome != zone.biome
  end

  # Ensure the item can be place
  def validate_placeable
    if @item.placeable == false || %w{tools consumables accessories}.include?(@item.category) || %w{accessory secondary}.include?(@item['inventory type'])
      @errors << "Can't place #{@item.category}"
    end
  end

  # Ensure block can be placed on
  def validate_placeover
    @errors << "Can't place items on anything but air or placeoverables" unless Game.item(peek[0]).placeover
  end

  # Ensure the player has the placed item
  def validate_inventory
    # Make sure the player has the placed item
    @errors << "Player doesn't have any #{item_id}" unless player.inv.contains?(@item_id)

    if @item.placing_cost
      @item.placing_cost.each_pair do |cost_item, cost_qty|
        @errors << "Player doesn't have enough cost item #{cost_item}" unless player.inv.contains?(Game.item_code(cost_item), cost_qty)
      end
    end
  end

  def validate_skill
    if sk = @item['placing skill']
      @errors << "Player isn't skilled enough to place" unless player.adjusted_skill(sk[0]) >= sk[1]
    end
  end

  # Make sure mod is allowable by item
  # (e.g. certain items allow player to mod, like rotateables; others don't)
  def validate_mod
    if item_mod > 0
      @errors << "Can't mod item type #{item_id}" unless ['rotation', 'change', 'sprite', nil].include?(@item.mod)

      case @item.mod
      when 'rotation'
        valid_mods = @item.rotation == 'mirror' ? [nil, 0, 4] : [nil, 0, 1, 2, 3]
        @errors << "Mod must be in #{valid_mods}" unless valid_mods.include?(item_mod)
      when 'change'
        @errors << "Mod must be within change range" unless item_mod <= @item.change.try(:size) || 0
      when 'sprite'
        @errors << "Can only use place mod" unless item_mod == @item['place mod']
      end
    end
  end

  def validate_karma_allowed
    if player.suppressed?
      @errors << "Player's karma is too low to place blocks"
      player.notify_error "Your karma is too low to place blocks."
    end
  end

  def validate_guild
    error = nil

    if @item.code == 915 && player.guild # signs/guild
      if !player.guild.leader?(player.id)
        error = "You already belong to a guild. Type /ghelp for more information."
      elsif player.guild.zone_id
        error = "An obelisk already exists for your guild. Type /ginfo to see where."
      end
    end

    if error
      @errors << error
      alert error
    end
  end

  def validate_role
    if @item.role && !player.roles.include?(@item.role)
      error_and_notify "You must be #{@item.role} to place that."
    end
  end

  # Ensure owned items are only placed in owned zones
  def validate_ownership
    if @item.ownership && !zone.owners.include?(player.id)
      @errors << msg = "You can only place these in worlds you own."
      alert msg
    end
  end

  # Ensure member items are only placed in owned/member zones
  def validate_membership
    if @item.membership && (!zone.owners.include?(player.id) && !zone.members.include?(player.id))
      @errors << msg = "You can only place these in owned or member worlds."
      alert msg
    end
  end

  # Ensure the block is not protected
  def validate_protected
    return if @item.field_place
    @errors << "Can't place in protected area" if zone.block_protected?(Vector2[@x, @y], player)
  end

  # Ensure an item that creates a force field will not overlap an existing field
  def validate_field
    if @item.field
      if zone.dish_will_overlap?([@x, @y], @item.field, player)
        @errors << msg = "Dish will overlap an existing protector."
        alert msg
      end

      # Prohibit placing dishes near spawn in newer worlds
      if zone.percent_explored < 0.667 && @item.field > 1 && zone.spawns_in_range(Vector2[x, y], 25).present?
        @errors << msg = "You cannot place dishes near spawn portals until the world has been more fully explored."
        alert msg
      end
    end
  end

  # Ensure block isn't placed closer than its spacing to another of the same kind
  def validate_spacing
    if @item.spacing && zone.meta_blocks_within_range(Vector2[x, y], @item.spacing-1, @item.spacing_items || @item.code).present?
      @errors << msg = "#{@item.title} must be at least #{@item.spacing} blocks away from other #{@item.title.downcase}s."
      alert msg
    end

    if @item.spawn_spacing && zone.spawns_in_range(Vector2[x, y], @item.spawn_spacing-1).present?
      @errors << msg = "#{@item.title} must be at least #{@item.spawn_spacing} blocks away from spawns."
      alert msg
    end
  end

  # Misc constraints
  def validate_constraints
    msg = nil

    if @item.place_constraints
      @item.place_constraints.each_pair do |key, value|
        case key
        when 'percent_explored'
          if zone.percent_explored < value
            @errors << msg = "The world must be at least #{(value * 100).to_i}% explored before #{@item.title.downcase}s can be placed."
          end
        end
      end
    end

    alert msg if msg.present?
  end

  # Adhere to zone item limits
  def validate_zone_limits
    msg = nil

    if limit = zone.item_player_limits[@item.code]
      if limit > 0
        if zone.meta_blocks_with_item(@item.code).count{ |mb| mb.player?(player) } >= limit
          @errors << msg = "You can only place #{limit} of these in this world."
        end
      else
        @errors << msg = "This item cannot be placed in this world."
      end
    end

    alert msg if msg.present?
  end

  def validate_spawn_cover
    zone.spawns_in_range([@x, @y], 3).each do |meta|
      # Less granular range check
      if Math.within_range?(meta.position, [@x, @y], 4)
        size = meta.item.block_size
        size = [size[0].clamp(1, 3), size[1].clamp(1, 3)]

        if @x >= meta.position.x && @x < meta.position.x + size.x && @y <= meta.position.y && @y > meta.position.y - size.y
          @errors << "Cannot place over spawn"
        end
      end
    end
  end

  # Don't allow placing physical blocks on top of certain NPCs
  def validate_place_over_entity
    if @item.shape
      npcs = zone.npcs_in_range(Vector2[@x, @y], 10)
      if npcs.any? { |npc| !npc.placeoverable? &&
        @x >= npc.position.x && @x < npc.position.x + npc.size.x &&
        @y <= npc.position.y && @y > npc.position.y - npc.size.y }
        @errors << "Cannot place over entity"
      end
    end
  end

  # Don't allow placing of too many entities
  def validate_place_entity
    if @item.place_entity
      if !player.can_place_entity?(@item)
        @errors << msg = "You do not have enough #{@item.title.downcase}s to place another."
        alert msg
      elsif cfg = Game.entity(@item.place_entity)
        if cfg.servant && zone.servants_of_player(player).size >= player.max_servants
          @errors << msg = "You can only operate #{player.max_servants} butler#{'s' if player.max_servants > 1} at a time at your current skill level."
          alert msg
        end
      else
        @errors << "Invalid place entity"
      end
    end
  end

  def peek
    @peek ||= zone.peek(@x, @y, @layer)
  end

  def validate_reach
    @errors << "Block isn't within player reach" unless (Vector2[@x, @y] - player.position).magnitude < player.max_placing_distance
  end

end
