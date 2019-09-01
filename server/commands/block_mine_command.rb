class BlockMineCommand < BaseCommand
  data_fields :x, :y, :layer, :item_id, :item_mod
  attr_accessor :item
  attr_accessor :surrogate

  def execute
    item_id = @item_id.to_s
    original_mod = peek[1]
    meta = zone.get_meta_block(@x, @y)
    owner_digest = zone.block_owner(x, y, layer)
    timer = @item.timer_mine ? zone.get_block_timer(@position) : nil

    # Change karma as appropriate
    # CHANGED 2017-02-18 - No longer checking karma on block mine
    # player.check_karma x, y, layer, item_id

    # Execute destroy use
    if @item.use.destroy
      if clazz = "Items::#{@item.use.destroy.camelize}".constantize
        clazz.new(player, zone: zone, item: @item, position: @position, meta: meta).destroy!
      end
    end

    # Update the block
    unless zone.static && !player.active_admin?
      new_item_id = @digging ? Game.item_code('ground/earth-dug') : (@item_mod == 0 ? 0 : @item_id)
      zone.update_block(@surrogate ? nil : player.entity_id, @x, @y, @layer, new_item_id, @item_mod, player)
    end

    # Fully remove block & process only if mod is 0
    if @item_mod == 0
      if @digging
        zone.dig_block(@position, @item_id, original_mod) unless zone.static
        player.event! :dig, @item
      else
        is_mod_inventory = @item.mod_inventory && original_mod >= @item.mod_inventory[0]
        player.inv.add_from_block @item, original_mod, is_mod_inventory || @surrogate

        # Execute timer if extant
        if timer
          zone.process_block_timer @position, timer[1], player
        end

        # Adjacent mine
        if adj = @item.adjacent_mine
          adj_pos = @position + Vector2[adj[0][0], adj[0][1]]
          if zone.in_bounds?(adj_pos.x, adj_pos.y)
            adj_peek = zone.peek(adj_pos.x, adj_pos.y, FRONT)
            adj_item = Game.item(adj_peek[0])
            if adj_item.group == adj[1]
              zone.update_block nil, adj_pos.x, adj_pos.y, FRONT, 0, 0
              player.inv.add_from_block adj_item, adj_peek[1], true
            end
          end
        end

        # Mining bonus
        if @item.mining_bonus && owner_digest == 0
          if rand < player.mining_bonus(@item)
            # Determine item to award
            inv_item = @item
            if @item.mining_bonus.item
              # If item def starts with hyphen, append to current item id; otherwise, def is whole item id
              inv_item = @item.mining_bonus.item =~ /^\-/ ?
                Game.item(@item.id + @item.mining_bonus.item) :
                Game.item(@item.mining_bonus.item)
            elsif @item.inventory
              inv_item = Game.item(@item.inventory)
            end

            if inv_item
              player.inv.add inv_item.code, @item.mining_bonus.double && rand < 0.25 ? 2 : 1, true
              player.notify @item.mining_bonus.notification, 4
            end
          end
        end

        # Increment counts
        zone.items_mined += 1
        player.mined_item(@item, @position, meta, owner_digest)
      end

      # Spawnin' some entities
      if @item.spawn_entity && (!@item.use['spawn'] || peek[1] == 0)
        zone.spawn_item_entities(@position, @item) unless zone.static
      end

      # Unset guild location
      if item_id.to_s == '915' && player.guild # signs/guild
        player.guild.clear_location
      end
    end
  end

  def validate
    @position = Vector2[@x, @y]

    run_if_valid :get_and_validate_item!

    # Check if we're digging
    @digging = Game.item(player.current_item).try(:action) == 'dig' && @item.diggable

    run_if_valid :validate_item_and_mod
    run_if_valid :validate_karma_allowed
    run_if_valid :validate_layer
    run_if_valid :item_check
    run_if_valid :air_check
    run_if_valid :entity_check
    run_if_valid :container_check
    run_if_valid :guild_check
    run_if_valid :validate_switch
    run_if_valid :validate_suppression
    run_if_valid :invulnerability_check unless active_admin?
    run_if_valid :validate_protection unless active_admin?
    run_if_valid :validate_raycast unless active_admin?
    run_if_valid :reach_check unless active_admin? || surrogate
    run_if_valid :skill_level_check
    run_if_valid :validate_custom_mine if @item.custom_mine
  end

  def validate_karma_allowed
    if player.suppressed?
      @errors << "Player's karma is too low for mining"
      player.notify_error "Your karma is too low to mine blocks."
    end
  end

  def validate_item_and_mod
    @errors << "Must have item or mod" unless @item_id and @item_mod
  end

  def validate_layer
    @errors << "Layer #{layer} invalid" unless layer.is_a?(Fixnum) && (layer > BASE && layer < LIGHT)
  end

  def item_check
    @errors << "Block at #{x},#{y} does not contain item #{item_id}" unless peek[0] == @item_id
  end

  def air_check
    @errors << "Can't mine air" if peek == 0
  end

  def entity_check
    # Prohibit mining entity-based items (e.g., turrets), as they have entities which need to be destroyed instead
    @errors << "Must destroy entity instead of block" if @item.entity
  end

  def container_check
    # Make sure this isn't a container with a special item or lock
    if @item.meta and meta = zone.get_meta_block(@x, @y)
      @errors << "Can't mine a container with a special item in it." if meta.special_item?
      @errors << "Can't mine a locked container" if meta.locked?
    end
  end

  def guild_check
    if item_id == 915 && meta = zone.get_meta_block(@x, @y)
      @errors << "Guild obelisk not owned by player." if meta.player_id != player.id.to_s
    end
  end

  def validate_switch
    if @item.use.switch
      if @meta = zone.get_meta_block(@x, @y)
        unless @meta.player?
          if switched = @meta.data['>']
            switched.each do |sw|
              switched_item = Game.item(zone.peek(sw[0], sw[1], FRONT)[0])
              if switched_item.use.switched
                @errors << msg = "This switch cannot be mined before its #{switched_item.title.downcase}."
                alert msg
                return false
              end
            end
          end
        end
      end
    end
  end

  def validate_suppression
    @errors << "Mining is suppressed" if player.suppress_mining?
  end

  def invulnerability_check
    # Validate invulnerable blocks
    @errors << "Can't mine invulnerable item" if @item.invulnerable
  end

  def skill_level_check
    # Validate skill requirement
    if req = @item['mining skill'] and player.adjusted_skill(req.first) < req.last
      @errors << "Player's skill is too low"
      case req.first
      when 'engineering'
        alert "Your engineering skill is too low to disable that."
      else
        alert "Your skill level is too low to mine that."
      end
      return
    end
  end

  # Ensure block is in reach
  def reach_check
    mining_position = player.position + Vector2[0, -1]
    @errors << "Block is out of reach" unless (@position - mining_position).magnitude < player.max_mining_distance
  end

  # Validate force fields
  def validate_protection
    return if @digging || @item.fieldable == false
    return if @item.fieldable == 'placed' && zone.block_owner(@position.x, @position.y, FRONT) == 0

    if zone.block_protected?(@position, player, @item.field.present?)
      @errors << "Can't mine protected block"
    end
  end

  # Validate line-of-sight
  def validate_raycast
    unless player.can_mine_through_walls?(@item)
      if @item.karma <= -5 && @item.block_size[0] == 1 && @item.block_size[1] = 1
        raycast = zone.raycast(player.position.fixed, @position)
        @errors << "Block is out of sight" if raycast.present?
      end
    end
  end

  def validate_custom_mine
    case @item.code
    when 891
      if zone.meta_blocks_with_item(891).size < 2 && !active_admin?
        @errors << msg = "You must keep at least one world teleporter active."
        alert msg
      end
    when 922
      if zone.minigame_at_position(Vector2[@position.x, @position.y])
        @errors << msg = "Minigame in progress."
        alert msg
      end
    end
  end

  def fail
    # Undo mining command if there are errors
    queue_message BlockChangeMessage.new(@x, @y, @layer, nil, peek[0], peek[1])
    player.inv.send_message item_id
  end

  private

  def peek
    @peek ||= zone.peek(@x, @y, @layer)
  end
end
