module Entity
  POS_MULTIPLIER = 100.0
  VEL_MULTIPLIER = POS_MULTIPLIER

  STATUS_EXITED = 0
  STATUS_ENTERED = 1
  STATUS_DEAD = 2
  STATUS_REVIVED = 3

  def self.included(base)
    base.extend(ClassMethods)

    attr_accessor :zone
    attr_accessor :entity_id, :owner_id, :ilk, :name, :details, :velocity, :direction, :target, :animation, :health
    attr_accessor :last_in_active_chunk_at, :last_in_immediate_chunk_at, :last_moved_at, :last_damaged_at, :last_critical_hit_at
    attr_accessor :client_directed, :block, :guard, :spawned, :character, :last_emote_at, :spawns, :cleared
    attr_accessor :active_minigame, :ephemeral

    def initialize_entity
      initialize_effects @config
      @last_emote_at = Time.now
      @last_critical_hit_at = Time.now
      @spawns = []

      if anims = @config.try(:animations)
        @animations_hash = anims.each_with_index.inject({}) do |hash, (anim, idx)|
          hash[anim.name] = idx
          hash
        end
      end
    end

    def spatial_position
      @position
    end

    def spatial_type
      @ilk
    end

    def clearable?
      @clear_delay ||= @config.try(:[], 'clear delay') || 1
      mobile? && !@guard && !@owner_id && !@character && !@active_minigame && (Time.now - @last_in_active_chunk_at > (5 * @clear_delay) || Time.now - @last_in_immediate_chunk_at > (15 * @clear_delay))
    end

    def mobile?
      npc? and !@block
    end

    def character?
      !!@character
    end

    def guard?
      !!@guard
    end

    def block?
      npc? and @block
    end

    def alive?
      @health > 0
    end

    def dead?
      !alive?
    end

    def velocity
      @velocity ||= Vector2.new(0, 0)
    end

    def position=(pos)
      @position = pos.is_a?(Vector2) ? pos : Vector2.parse(pos)
      check_block_position_changed
    end

    def position
      @position
    end

    def direction=(dir)
      @direction = dir
    end

    def check_block_position_changed
      # Check zone for triggers if rounded position changed
      if @zone && @position
        pos_fixed = @position.fixed
        unless pos_fixed == @pos_fixed
          #p "change #{@pos_fixed} => #{pos_fixed}" if player? && Deepworld::Env.development?
          return unless block_position_changed(pos_fixed)
        end
        @pos_fixed = pos_fixed
      end
    end

    def block_position_changed(pos)
      if zone.in_bounds?(pos.x, pos.y)

        # If no pos_fixed, this is first block check
        if @pos_fixed.nil?
          block_entered pos
          @last_passable_block ||= @pos_fixed

        # Otherwise, determine which blocks we need to check
        else
          blocks_moved = (pos.x - @pos_fixed.x).abs + (pos.y - @pos_fixed.y).abs

          # If player has moved only one block, or has moved far, just check the one block
          if blocks_moved == 1 || blocks_moved > 5
            return false unless block_entered(pos)

          # Otherwise, check all blocks en route
          else
            if @pos_fixed.x != pos.x
              xs = @pos_fixed.x < pos.x ? @pos_fixed.x.upto(pos.x) : @pos_fixed.x.downto(pos.x)
              xs.each do |x|
                unless x == @pos_fixed.x
                  return false unless block_entered(Vector2[x, @pos_fixed.y])
                end
              end
            end
            if @pos_fixed.y != pos.y
              ys = @pos_fixed.y < pos.y ? @pos_fixed.y.upto(pos.y) : @pos_fixed.y.downto(pos.y)
              ys.each do |y|
                unless y == @pos_fixed.y
                  return false unless block_entered(Vector2[@pos_fixed.x, y])
                end
              end
            end
          end
        end
      end

      true
    end

    def block_entered(pos)
      if zone.in_bounds?(pos.x, pos.y)

        # Front block responsible for physics & effects
        front_peek = zone.peek(pos.x, pos.y, FRONT)
        item = Game.item(front_peek[0]) || Game.item(0)

        # Handle triggers
        if item && item.use.trigger
          Items::Trigger.new(nil, zone: zone, entity: self, position: pos, item: item).use!
        end

        # Check for overlap with physical blocks
        if player?
          impassible = zone.blocked_to_player?(pos.x, pos.y)
          rejected = false
          bump_y = 0 # When moving up, we bump player down a bit due to double block height

          # If obstacle, check if last block was an obstacle too. If so, reset position.
          if @last_passable_block && @one_block_ago && @two_blocks_ago
            one_block_ago_impassible = zone.blocked_to_player?(@one_block_ago.x, @one_block_ago.y)
            two_blocks_ago_impassible = zone.blocked_to_player?(@two_blocks_ago.x, @two_blocks_ago.y)

            if one_block_ago_impassible
              if two_blocks_ago_impassible
                rejected = true
                track_block_overlap pos

              else
                direction = pos - @one_block_ago

                # If moved two blocks in same direction
                if direction == @one_block_ago - @two_blocks_ago
                  if zone.blocked_to_player?(@one_block_ago.x + direction.perp.x, @one_block_ago.y + direction.perp.y) &&
                     zone.blocked_to_player?(@one_block_ago.x - direction.perp.x, @one_block_ago.y - direction.perp.y)
                    rejected = true
                    track_block_overlap pos
                    bump_y = direction.y == -1 ? 1 : 0
                  end
                end
              end
            end
          end

          # Reject if necessary
          if rejected && @play_time > 3600 && !zone.tutorial? && (role?('glitch') || zone.config['glitch_proof'])
            @position = @pos_fixed = @one_block_ago = @two_blocks_ago = @last_passable_block
            queue_message PlayerPositionMessage.new(@position.x, @position.y + bump_y, @velocity.x, @velocity.y)
            return false
          else
            @last_passable_block = pos unless impassible
            check_proximity true
          end

          @two_blocks_ago = @one_block_ago
          @one_block_ago = pos
        end

        @pos_fixed = pos
      end

      true
    end

    def target
      @target ||= Vector2.new(0, 0)
    end

    def check_proximity(force = false)
      if force || !@last_proximity_check || Time.now > @last_proximity_check + 1.0
        @last_proximity_check = Time.now
      end
    end

    def position_array
      if position && velocity
        [
          @entity_id,
          (position.x * POS_MULTIPLIER).to_i,
          (position.y * POS_MULTIPLIER).to_i,
          (velocity.x * VEL_MULTIPLIER).to_i,
          (velocity.y * VEL_MULTIPLIER).to_i,
          @direction || 0,
          (target.x * POS_MULTIPLIER).to_i,
          (target.y * POS_MULTIPLIER).to_i,
          @animation
        ]
      else
        nil
      end
    end

    def animate(name_or_index)
      if name_or_index.is_a?(Fixnum)
        @animation = name_or_index
      elsif @animations_hash
        @animation = @animations_hash[name_or_index] || 0
      end
    end

    def owner_id=(oid)
      @owner_id = oid
      @behavior.react :set_owner_id, oid
    end

    def status(status_code = STATUS_ENTERED, deets = nil)
      deets ||= details
      [entity_id, ilk, name, status_code, deets]
    end

    def queue_tracked_messages(message)
      @zone.players.each do |player|
        player.queue_message message if player.tracking_entity?(entity_id)
      end
    end

    def self.exit_status(entity_id)
      [entity_id, nil, nil, 0, nil]
    end

    def random_loot(player = nil)
      # If player placed this entity and we have specific loot for that, use it
      if player_placed? && @config.placed_loot
        return @config.placed_loot
      end

      # Weapon-based loot
      if player && @config.loot_by_weapon
        options = @config.loot_by_weapon[Game.item(player.current_item).try(:id)]
        return options.random_by_frequency if options.present?
      end

      # Random loot
      if @config.loot
        @config.loot.random_by_frequency || @config.loot.first
      else
        nil
      end
    end

    def group
      'player'
    end

    def player?
      @is_player ||= (group == 'player')
    end

    def player_placed?
      block? && meta_block && meta_block.player?
    end

    def report_health
      @zone.change_entity self, { h: (self.health * 100).to_i }
    end

    def attack_range(item)
      item ? item.damage_range || 0 : 0
    end

    def spawn_died!(entity)
      @spawns -= [entity.entity_id]
    end

    def damage!(amount, type = nil, attacker = nil, send_message_if_player = true, explosive = false)
      return unless damageable?

      if self.health > 0
        # Behave based on damage
        @behavior.react :damage, [type, amount] if @behavior

        # If a block object and protected, don't die
        if @block && @zone.block_protected?(@block, attacker)
          # TODO: Allow temporary disablement

        # Unprotected, so get hurt
        else
          self.health -= amount
          self.die!(attacker, explosive) if self.health <= 0
        end

        after_damage send_message_if_player
        @last_damaged_at = Time.now
      end
    end

    def damage_if_in_field_range!(blocks, scale_damage = true)
      blocks.each do |block|
        if block.item.field_damage
          range = block.item.field_damage[2]
          damage_if_in_range! block.position, range, block.item.field_damage, scale_damage
        end
      end
    end

    def damage_if_in_range!(origin, range, damage, scale_damage = true)
      distance = (position - origin).magnitude
      if distance < range
        amt = damage[1] > 0 ? damage[1] : 2
        amt *= 1.0 - (distance / range) if scale_damage
        damage! amt, damage[0] if amt > 0.1
      end
    end

    def after_damage(send_message_if_player = nil)
      # Overridden in player
    end

    def fx_teleport!
      @zone.queue_message EffectMessage.new(position.x * Entity::POS_MULTIPLIER, position.y * Entity::POS_MULTIPLIER, 'bomb-teleport', 4)
    end

    def die!(entity = nil, explosive = false)
      if entity && entity.player?
        if !spawned || entity.zone.beginner?
          # Give player XP / stats (if allowed)
          if entity.grant_xp?(:kill) && !player_placed?
            entity.track_kill self, explosive

            # Give other attackers a sidekick achievement
            if sidekicks = active_attackers.reject!{ |a| a != entity }
              sidekicks.each { |s| Achievements::SidekickAchievement.new.check(entity) }
            end

            if xp = @config.xp
              #if entity.mobs_killed[self.code] >=
              entity.add_xp xp
            end
          end

          # Drop loot as block if explosive, inventory if not
          if loot = self.random_loot(entity)
            if item = Game.item(loot.item)
              qty = loot.quantity || 1
              if explosive && item.category != 'consumables' && item.category != 'accessories' && !item.entity
                current_front_item = Game.item(@zone.peek(@position.x.to_i, @position.y.to_i, FRONT)[0])
                if current_front_item.placeover
                  mod = item.mod == 'stack' ? qty : 0
                  @zone.update_block nil, @position.x.to_i, @position.y.to_i, FRONT, item.code, mod
                end
              else
                entity.inv.add(item.code, qty, true) unless item.code == 0
              end
            end
          end

        # Spawn kills send a different event
        else
          entity.event! :kill_spawn, self
        end
      end

      # Death callback for owner entity/player
      if @owner_id
        # Player-owned
        if @servant
          if player = @zone.find_player_by_id(@owner_id)
            player.servant_died! self
          end
        # Entity-owned
        else
          if entity = @zone.entities[@owner_id]
            entity.spawn_died! self
          end
        end
      end

      # Minigame callback
      if @active_minigame
        @active_minigame.participant_died! self, entity
      end

      @behavior.react :death, true if @behavior

      @zone.update_block nil, @block.x, @block.y, FRONT, 0 if @block   # Block entities get their base block destroyed on death
      @zone.remove_entity self
    end

    def inspect
      "<Entity ##{@entity_id} #{@config.type}>"
    end

    def meta_block
      @meta_block ||= @zone.get_meta_block(position.x, position.y)
    end

    def code
      @config.try(:code)
    end

    def ilk_name
      @config.try(:name)
    end

    def graph
      @config.try(:graph)
    end

    def emote(msg)
      @zone.queue_message ChatMessage.new([@entity_id, msg, 'e'])
      @last_emote_at = Time.now
    end

    def change(params)
      @zone.queue_message EntityChangeMessage.new([@entity_id, params])
    end

  end

  module ClassMethods

  end

end
