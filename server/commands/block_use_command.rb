class BlockUseCommand < BaseCommand
  data_fields :x, :y, :layer, :use_data

  def execute
    peek = zone.peek(@x, @y, @layer)
    current_mod = peek[1]

    if @item.use.present?
      meta = zone.get_meta_block(@x, @y)

      # If enemy use only, don't let originating player or stealth player use it
      if @item.use.enemy
        return unless player.can_be_targeted?
        return if meta && meta.player_or_followee?(player)
      end

      # If this is a public-only use (e.g. use on a protected item not by the owner), only proces that
      if @public
        case @item.use.public
        when 'moderation'
          Items::Moderation.new(player, position: Vector2[@x, @y], meta: meta, item: @item).use!
        when 'landmark'
          if player.owns_current_zone?
            Items::Moderation.new(player, position: Vector2[@x, @y], meta: meta, item: @item).use!
          else
            Items::Landmark.new(player, position: Vector2[@x, @y], meta: meta, item: @item).use!
          end
        when 'note'
          Items::Note.new(player, { meta: meta, item: @item }).use!
        when 'owner'
          Items::Owner.new(player, { item: @item, meta: meta }).use!
        end

        return
      end

      @item.use.each_pair do |use, config|
        case use

        when 'legacy_wardrobe'
          player.show_dialog [{ 'title' => 'Changing appearance', 'text' => 'Your appearance is now changed in your profile. Open the profile panel by tapping your picture in the upper left, then tap on the "appearance" tab at the bottom. You can change clothes or randomize your look at any time!' }]

        when 'dialog', 'create dialog'
          if @process_dialog
            case config.target
            when 'meta'
              next if use == 'create dialog' && meta && meta.data['cd']
              metadata = meta.try(:data) || {}
              prev_data = metadata.dup
              values = @form.try(:values) || @use_data

              config.sections.each_with_index do |section, idx|
                if key = section.input['key']
                  text = values[idx]
                  if section.input['sanitize']
                    player.track_obscenity! if Deepworld::Obscenity.is_obscene?(text)
                    text = Deepworld::Obscenity.sanitize(text)
                    text.gsub! /[^\s]/, '.' if player.muted
                  end
                  metadata[key] = text
                elsif section.input.mod
                  options = section.input.options
                  mod = options.index(values[idx]) || 0
                  mod *= section.input.mod_multiple if section.input.mod_multiple
                  zone.update_block nil, @x, @y, @layer, @item.code, mod, zone.block_owner(@x, @y, @layer)
                end
              end

              metadata['cd'] = true if use == 'create dialog' # Mark item as dialogged if only a 'create dialog' type

              # Update the guild
              if @item.code == 915 # signs/guild
                update_guild(metadata, prev_data)
              else
                zone.set_meta_block @x, @y, @item, player, metadata
              end

            when 'appearance'
              # Iterate through dialog sections and assign options to player's appearance
              @form.input_sections.each_with_index do |section, index|
                if key = section.input['key']
                  player.appearance[key] = use_data[index]
                end
              end

              player.send_peers_status_update
            end
          end

        when 'target teleport'
          if meta
            # New target teles
            if meta['px']
              Items::TargetTeleport.new(player, position: Vector2[@x, @y], item: @item, meta: meta).use!

            # Legacy target zone
            elsif new_zone_name = meta.data['z']
              new_position = meta.data['zp']

              if new_zone_name.present?
                new_position = new_position.split(' ').map(&:to_i) if new_position.present? && new_position.match(/^\d+ \d+$/)
                Zone.where(name: new_zone_name).callbacks(false).first do |new_zone|
                  if new_zone
                    player.send_to new_zone.id, true, new_position.present? ? new_position : nil
                  else
                    alert "Couldn't find zone #{new_zone_name}"
                  end
                end
              end
              break

            # Legacy target position
            elsif new_position = meta.data['zp']
              if new_position.present? && new_position.match(/^\d+ \d+$/)
                new_position = new_position.split(' ').map(&:to_i)
                player.teleport! Vector2[new_position[0], new_position[1]], false
                break
              end
            end
          end

        when 'note'
          Items::Note.new(player, { meta: meta }).use!

        when 'transmit'
          Items::Transmitter.new(player, position: Vector2[@x, @y]).use!

        when 'timer'
          zone.add_block_timer Vector2[@x, @y], @item.timer_delay, config, player

        when 'change'
          zone.update_block player.entity_id, @x, @y, @layer, @item.code, current_mod == 0 ? 1 : 0, player

        when 'claimable'
          Items::Claimable.new(player, item: @item, position: Vector2[@x, @y]).use!

        when 'inventory'
          #alert "You dropped some #{@use_data}"

        when 'challenge'
          Items::Challenge.new(player, position: Vector2[@x, @y], meta: meta, item: @item).use!

        when 'container'
          Items::Container.new(player, position: Vector2[@x, @y], item: @item, mod: current_mod, meta: meta).use!

        when 'fertilizer'
          Items::Fertilizer.new(player, position: Vector2[@x, @y], item: @item).use!

        when 'minigame'
          Items::Minigame.new(player, position: Vector2[@x, @y], item: @item, meta: meta).use!

        when 'reset'
          Items::Reset.new(player, position: Vector2[@x, @y], item: @item, meta: meta).use!

        when 'switch'
          if @use_data.blank?
            Items::Switch.new(player, position: Vector2[@x, @y], item: @item, mod: current_mod).use!
          end

        when 'quipper'
          Items::Quipper.new(player, position: Vector2[@x, @y], item: @item).use!

        when 'burst'
          Items::Burst.new(player, position: Vector2[@x, @y], item: @item).use!

        when 'recycler'
          if can_use_machine?(:recycler)
            Items::Recycler.new(player).use!
          end

        when 'world_machine'
          clazz = "Items::WorldMachines::#{config.capitalize}"
          clazz.constantize.new(player, position: Vector2[@x, @y], item: @item, meta: meta).use!

        when 'notify'
          if meta && meta['msg']
            unless player.used_notification_blocks.include?(meta.index)
              msg = meta['param'].present? ? [meta['msg'], meta['param']] : meta['msg']
              player.notify msg, meta['code'].to_i
              player.used_notification_blocks << meta.index
            end
          end

        when 'waypoint'
          if meta && meta['w'] && meta['v']
            key = meta['w']
            player.waypoints[key] = meta['v']
            zone.player_event player, :waypoint, [key, meta['v']]
          end

        when 'teleport'
          if meta = zone.get_meta_block(@x, @y) && peek[1] == 1
            # If destination was provided, teleport there
            if @use_data
              if destination_meta = zone.get_meta_block(@use_data.first, @use_data.last)
                if ['teleport', 'zone teleport'].any?{ |u| destination_meta.item.use[u] }
                  width = destination_meta.item.block_size[0]
                  x_offset = (width-1)*0.5
                  player.teleport! Vector2[destination_meta.x + x_offset, destination_meta.y], false, 'teleport'
                end
              end
            end

          # No meta info, so player is first to discover - set meta and notify
          else
            zone.update_block nil, @x, @y, @layer, @item.code, 1
            notify 'You repaired a teleporter!', 10
            notify_peers "#{player.name} repaired a teleporter.", 11
            queue_message EffectMessage.new((@x + 0.5) * Entity::POS_MULTIPLIER, (@y + 0.5) * Entity::POS_MULTIPLIER, 'sparkle up', 20)

            # Teleporter discovery achievement
            Achievements::DiscoveryAchievement.new.check(player, @item)
            player.add_xp :teleporter_repair
          end

        when 'spawn teleport'
          Items::SpawnTeleport.new(player, position: Vector2[@x, @y], item: @item).use!

        when 'directive'
          Items::Directive.new(player, { directive: peek[1], position: Vector2[@x, @y] }).use!

        when 'geck'
          if can_use_machine?(:geck)
            alert zone.purifier_active? ? 'The Purifier is working.' : 'The Purifier is blocked - clear a path to the sky!'
          end

        when 'composter'
          if can_use_machine?(:composter)
            compost_earth = 10
            compost_giblets = 3
            if player.inv.contains?(Game.item_code('ground/earth'), compost_earth) and player.inv.contains?(Game.item_code('ground/giblets'), compost_giblets)
              player.inv.remove Game.item_code('ground/earth'), compost_earth
              player.inv.remove Game.item_code('ground/giblets'), compost_giblets
              player.inv.add Game.item_code('ground/earth-compost'), 1
              player.inv.send_message %w{ground/earth ground/giblets ground/earth-compost}.map{ |i| Game.item_code(i) }
              player.queue_message EffectMessage.new(@x * Entity::POS_MULTIPLIER, @y * Entity::POS_MULTIPLIER, 'composter', 1)
            else
              alert "You need #{compost_earth} earth and #{compost_giblets} giblets to generate compost."
            end
          end

        when 'expiator'
          if can_use_machine?(:expiator)
            ghosts = zone.npcs_in_range(Vector2[@x, @y], 5, ilk: 1)
            if ghosts.size > 0
              zone.expiate_ghosts(player, ghosts)
              zone.queue_message EffectMessage.new((@x + 0.5) * Entity::POS_MULTIPLIER, (@y + 1.5) * Entity::POS_MULTIPLIER, 'expiate', 10)

              notify 'You released a lost soul!', 10
              notify_peers "#{player.name} released a lost soul.", 11
              player.add_xp :deliverance
            else
              alert "No ghosts in range."
            end
          end

        when 'warmth'
          player.warm if peek[1] == 1

        when 'spawn'
          if @item.spawn_entity && peek[1] == 0
            zone.spawn_item_entities Vector2[@x, @y], @item
            zone.update_block nil, @x, @y, FRONT, peek[0], 1, zone.block_owner(@x, @y, FRONT)
          end

        when 'checkpoint'
          # Update the spawn point, if it changes
          if player.spawn_point.to_a != [@x, @y]
            player.update(spawn_point: [@x, @y])
          end

        when 'meta_change'
          Items::MetaChange.new(player, position: Vector2[@x, @y], item: @item).use!

        when 'market'
          if player.owns_current_zone?
            sections = [{ 'title' => 'Convert to market?', 'text' => 'Are you sure you want to convert this world to a Market? This is a single-use item.' }]
            player.show_dialog({ 'actions' => 'yesno', 'sections' => sections }, true) do |resp|
              if zone.peek(@x, @y, FRONT)[0] == @item.code
                zone.update_block nil, @x, @y, FRONT, 0, 0
                player.inv.save! do
                  zone.update market: true do |z|
                    zone.reconnect_all! 'Changed to Market'
                  end
                end
              else
                player.alert "Please re-place market converter."
              end
            end
          else
            player.alert "You must own this world to convert it to a market."
          end
        end
      end
    end
  end

  def update_guild(metadata, prev_data)
    if guild = player.guild
      guild.apply_metadata(metadata)

      guild.validate do |g|
        if g.errors.empty?
          guild.save
          zone.set_meta_block @x, @y, @item, player, metadata
        else
          alert({ sections: [{ text: g.errors.join("\n") }] })
          zone.set_meta_block @x, @y, @item, player, prev_data
        end
      end
    end
  end

  def validate
    @errors << "cheater" if player.role?("cheater")

    run_if_valid :get_and_validate_item!, zone.peek(@x, @y, @layer).first
    run_if_valid :validate_reach
    return unless @errors.empty?

    @use = @item.use

    unless @use.present?
      @errors << "Item is not usable"
      return
    end

    # Process dialog if use includes one and a.) it's the only use type or b.) there are multiple use types but use data was submitted
    @process_dialog = (@use['dialog'] || @use['create dialog']) && (@use.size == 1 || @use_data.present?)

    meta = zone.get_meta_block(@x, @y)

    unless player.active_admin?
      # Don't allow protected items to be used by other players
      if @use['protected'] && meta
        if meta.player_id
          if meta.player_id != player.id.to_s
            # If there is a public use, allow that
            if @use['public']
              @public = true

            # Otherwise, deny use
            else
              @errors << "Player #{player.name} isn't owner of this block"
              alert "Sorry, that belongs to somebody else."
              return false
            end
          end
        end
      end

      # Don't allow fieldable items to be used if protected
      if @use['fieldable'] && zone.block_protected?(Vector2[@x, @y], player, false, nil, false, true)
        @errors << msg = "This item cannot be used while protected."
        alert msg
        return false
      end

      # Don't allow create dialogs to be used by non-creator
      if @process_dialog && @use['create dialog'] && meta && meta.player_id != player.id.to_s
        @errors << "Only creator can use dialog for this block"
      end

      # Validate lock / key
      if @use['container'] && meta && meta.locked? && !player.has_key?(meta.key)
        @errors << "Container isn't unlockable by player"
        alert "You need a special key to unlock this."
        return false
      end
    end

    # Validate dialog input with Form class
    if @process_dialog
      dialog = @use['create dialog'] && (!meta || !meta.data['cd']) ? @use['create dialog'] : @use['dialog']
      if dialog
        @form = Form.new(player, dialog, @use_data)
        @form.validate
        @errors += @form.errors
      end
    end

    p "[BlockUseCommand] Use errors: #{@errors}" if @errors.present? && Deepworld::Env.development?

    return @errors.blank?
  end

  def can_use_machine?(machine)
    total_parts = zone.machine_parts_count(machine)
    found_parts = zone.machine_parts_discovered_count(machine)
    description = zone.machine_description(machine)

    # Notify that parts still need to be found
    if found_parts < total_parts - 1
      parts_left = total_parts - 1 - found_parts
      parts_msg = "#{parts_left} part#{parts_left != 1 ? 's' : ''}"
      alert "#{parts_msg} of the #{description} still need to be found."
      false

    # All parts found, so activate machine
    elsif found_parts < total_parts
      zone.discover_machine_part! machine, @item.code, player
      zone.update_block nil, @x, @y, FRONT, @item.code, 1
      notify "You activated the #{description}!", 10
      notify_peers "#{player.name} activated the #{description}!", 11

      # Discovery achievement
      Achievements::DiscoveryAchievement.new.check(player, @item)

      false

    # Ready to use
    else
      true
    end
  end

  def public?
    !!@public
  end

  def validate_reach
    return if player.active_admin?

    use_position = (player.position || Vector2[0, 0]) + Vector2[0, -1]
    @errors << "Block isn't within player reach" unless (Vector2[@x, @y] - use_position).magnitude < player.max_mining_distance
  end

  def should_send?
    return true unless zone.static?

    allow = ['dialog', 'create dialog', 'target teleport', 'container', 'note', 'notify', 'teleport', 'warmth', 'spawn teleport', 'checkpoint']
    return (allow & @item.use.keys).present?
  end

end
