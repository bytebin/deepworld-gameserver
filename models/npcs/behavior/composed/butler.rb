module Behavior
  class Butler < Rubyhave::Selector

    attr_reader :owner, :last_directed_at

    def on_initialize
      @last_directed_at = Time.now
      @last_commanded_at = Time.now
      @directed_blocks = Set.new
      @ticks = 0
    end

    def after_add
      # Locked behaviors

      mover = add_child(behavior(:butler_blocker))
      mover.setup_for_action 'move', :directed_fly

      miner = add_child(behavior(:butler_blocker))
      miner.setup_for_action 'mine', :servant_mine

      placer = add_child(behavior(:butler_blocker))
      placer.setup_for_action 'place', :servant_place

      filler = add_child(behavior(:butler_blocker))
      filler.setup_for_action 'fill', :servant_fill

      blaster = add_child(behavior(:butler_blocker))
      blaster.setup_for_action 'blast', :servant_blast

      drain = add_child(behavior(:butler_blocker))
      drain.setup_for_action 'drain', :servant_drain

      dump = add_child(behavior(:butler_blocker))
      dump.setup_for_action 'dump', :servant_dump

      excavate = add_child(behavior(:butler_blocker))
      excavate.setup_for_action 'excavate', :servant_excavate

      set :servant, self
      set :directed_blocks, @directed_blocks
      @created_at = Time.now

      set :level, entity.config['level'] || 1
    end



    # ===== Step ===== #

    def behave
      super

      # If lifetime has been exceeded, despawn or respawn
      if Time.now > @despawn_at
        # Respawn if a command has been sent in the last five minutes or if directed blocks remain
        if Time.now < @last_commanded_at + 5.minutes || @directed_blocks.size > 0
          respawn!
        else
          despawn!
        end
      end

      # Send color updates to indicate duration left
      if @ticks % 16 == 0
        perc = (Time.now - @created_at) / life_duration
        color = Color::RGB.new(255.lerp(10, perc), 70.lerp(5, perc), 5).html
        glow color
      end

      # Send orientation
      if @ticks % 2 == 0
        block = @directed_blocks.try(:first)
        unless block
          target = get(:target)
          if target.is_a?(Vector2)
            block = target
          elsif target.respond_to?(:position)
            block = target.position
          end
        end

        orient_at block if block
      end

      @ticks += 1
    end


    # ===== Interaction ===== #

    def react(message, params)
      case message
      when :set_owner_id
        setup_owner zone.find_player_by_id(params)

      when :interact
        player = params.first
        is_item = params.last.is_a?(Array) && params.last.first == 'item'

        # If an item, set as usable item
        if is_item
          item_code = params.last.last.to_i
          if item_code > 0 && item = Game.item(item_code)
            set :item, item
            entity.emote "Ready to use #{item.title.downcase}."
          end

        # Otherwise, just a normal interaction
        else
          attempt_interaction_with player
        end

      when :direct_mode
        set_directive params.last.downcase

      when :direct
        direct params.last

      when :death
        pos = Vector2[entity.position.x + 0.5, entity.position.y + 0.5]
        zone.queue_message EffectMessage.new(pos.x * Entity::POS_MULTIPLIER, pos.y * Entity::POS_MULTIPLIER, 'bomb-teleport', 4)

      end

      @last_commanded_at = Time.now
    end

    def setup_owner(owner)
      set :owner, @owner = owner

      # Follow player if no active directive
      follow = add_child(behavior(:sequence))
      ineq = follow.add_child behavior(:inequality)
      ineq.property = :directive
      ineq.value = 'move'
      follow.add_child behavior(:owner_target)
      follow_move = follow.add_child(behavior(:selector))
      follow_move.add_child behavior(:servant_teleport)
      follow_move.add_child behavior(:fly_toward)
      follow_move.add_child behavior(:fly_seek)

      extend_life
    end

    def extend_life
      @despawn_at = Time.now + life_duration
    end

    def life_duration
      if @owner
        seconds = 300.lerp(600, @owner.adjusted_skill('automata') / 15.0)
        seconds *= 1.5 if @owner.inv.accessory_with_use('butler extension')
        seconds
      else
        0
      end
    end

    def respawn!
      cost_item = Game.item('accessories/battery')
      if @owner.inv.contains?(cost_item.code)
        cost_qty = 1
        @owner.inv.remove cost_item.code, cost_qty, true
        @owner.emote "-#{cost_qty} #{cost_item.title}"
        extend_life
        effect! :teleport
      else
        despawn!
      end
    end

    def despawn!
      entity.die!
    end

    def effect!(type)
      case type
      when :teleport
        @owner.zone.queue_message EffectMessage.new((entity.position.x + 0.5) * Entity::POS_MULTIPLIER, (entity.position.y + 0.5) * Entity::POS_MULTIPLIER, 'bomb-teleport', 4)
      end
    end


    # ===== Interaction ===== #

    def attempt_interaction_with(player)
      # If owner is interacting, respond
      if can_interact_with?(player)

        # Show options dialog if double activated
        if @last_reacted_at && Time.now < @last_reacted_at + 0.5
          player.show_dialog directive_dialog, true, { type: :butler, entity_id: entity.entity_id }
        else
          player.notify_start_directing(entity)
        end

        @last_reacted_at = Time.now

      # Not owner, so emote denial message
      else
        entity.emote Game.fake('butler-denial')
      end
    end

    def can_interact_with?(player)
      player == @owner
    end


    # ===== Directives ===== #

    def set_directive(directive)
      set :directive, directive
      @directive = directive

      # Shutdown - simple die
      if @directive == 'shutdown'
        entity.emote Game.fake('butler-shutdown')
        entity.die!

      # Other directives involve behavior tree
      else
        entity.emote Game.fake('butler-direct').sub(/\$\$/, @directive).capitalize
        @owner.notify_start_directing(entity)
      end
    end

    def self.directives
      %w{follow move mine place blast excavate drain clone craft teleport stun ward shield scan shutdown dump fill}
    end

    def available_directives
      unless @available_directives
        @available_directives = @owner.admin? ? self.class.directives : @owner.directives.dup
        @available_directives << 'dump' if @available_directives.include?('drain')
        @available_directives -= level_2_directives unless get(:level) >= 2
        @available_directives -= level_3_directives unless get(:level) >= 3
      end
      @available_directives
    end

    def level_2_directives
      %w{excavate teleport fill}
    end

    def level_3_directives
      %w{blast}
    end

    def selectable_directives
      %w{move mine place blast excavate drain dump clone craft shutdown fill}
    end

    def directive_dialog
      directive_options = (available_directives & selectable_directives).sort - ['shutdown'] + ['shutdown']

      d = [
        {
          title: "Your orders?",
          input: {
            type: 'text select',
            options: directive_options.map(&:capitalize),
            key: 'directive'
          }
        }
      ]

      txt = "Find Directive Units in chests and visit ButlerBot HQ in Pocklington to activate new directives."
      txt = "You do not currently have any available directives. " + txt if available_directives.blank?
      d <<  { text: txt }

      d
    end



    # ===== Directing ===== #

    # Append block to directed set
    def direct(block)
      return if block == entity.position

      # Clear existing blocks if enough time has elapsed
      if Time.now > @last_directed_at + 2.0
        @directed_blocks.clear
      end

      @directed_blocks << block
      @last_directed_at = Time.now
      set :last_directed_at, @last_directed_at
    end


    # ===== Animation ===== #

    def orient_at(block)
      x = block.x > entity.position.x ? 1 : block.x < entity.position.x ? -1 : 0
      y = block.y > entity.position.y ? 1 : block.y < entity.position.y ? -1 : 0
      orient Vector2[x, y]
    end

    def orient(direction)
      change o: [direction.x, direction.y]
    end

    def glow(color)
      change c: color.sub(/\#/, '')
    end

    def change(params)
      entity.zone.change_entity entity, params
    end
  end

  class ServantStaticBehavior

    def initialize(servant, directive)
      @servant = servant
      @directive = directive
    end

    def can_behave?
      @servant.available_directives.include?(@directive)
    end

  end

  class ButlerBlocker < Rubyhave::Sequence
    include TargetHelpers

    def setup_for_action(directive, behavior_name = nil)
      @directive = directive

      local :target

      add_child behavior(:directed_target)

      actions = add_child(behavior(:selector))
      if behavior_name
        action_behavior = actions.add_child behavior(behavior_name)
        class << action_behavior
          include ButlerBlockerAction
        end
      end
      actions.add_child(behavior(:fly_toward)).random = false
      seek = actions.add_child(behavior(:fly_seek))
      seek.random = false
      seek.direction = :x
      seek2 = actions.add_child(behavior(:fly_seek))
      seek2.random = false
      seek2.direction = :y
    end

    def can_behave?(params = {})
      get(:owner) && get(:directive) == @directive
    end

    module ButlerBlockerAction

      def protected?(block)
        if zone.block_protected?(block, get(:owner))
          if !@last_protected_emote || Time.now > @last_protected_emote + 2.seconds
            entity.emote "This area is protected."
            @last_protected_emote = Time.now
          end
          true
        else
          false
        end
      end

      def adjusted_action_interval
        @action_interval - (@action_interval * ((get(:level) - 1) * 0.25))
      end

    end

  end


end
