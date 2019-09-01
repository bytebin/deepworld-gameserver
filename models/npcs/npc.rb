module Npcs
  class Npc
    include Entity
    include Entities::Effectable

    attr_accessor :config, :blocked, :move, :last_climb_side, :speed, :chunk_index
    attr_reader :base_speed, :behavior, :metadata, :size, :die_at, :category

    def initialize(config_or_key, zone, position)
      @zone                         = zone

      process_config(config_or_key)
      p "Warning: no entity config for key '#{config_or_key}'" unless @config

      @time                         = Time.now
      @ilk                          = @config.code
      @position                     = position.dup || Vector2.new(0, 0)
      @velocity                     = Vector2.new(0, 0)
      @chunk_index                  = zone.chunk_index(position.x, position.y)
      @move                         = Vector2.new(0, 0)
      @animation                    = 0
      @health                       = @config.health
      @last_in_active_chunk_at      = Time.now
      @last_in_immediate_chunk_at   = Time.now
      @last_moved_at                = Time.now
      @base_speed                   = @config['speed'] || 3.0
      @type                         = @config.type
      @speed                        = @base_speed * (0.9..1.1).random
      @speed_variance               = Range.new(@config['speed_variance'].first, @config['speed_variance'].last) if @config['speed_variance']
      @next_speed_variance_at       = Time.now
      @blocked                      = {}
      @last_climb_side              = 1
      @direction                    = [-1, 1].random
      @metadata                     = {}
      @size                         = @config['size'] ? Vector2[@config['size'][0], @config['size'][1]] : Vector2[1, 1]
      @servant                      = @config['servant']
      @category                     = @config['name'].split('/').first

      @behave_interval              = @config['block'] ? 0.5 : 0.3
      @last_behaved_at              = Time.now + (rand * @behave_interval)

      if @config['duration']
        @die_at = Time.now + @config['duration']
      end

      # Behavior tree
      if @config['behavior']
        begin
          @behavior = Rubyhave::BehaviorTree.create(@config['behavior'], self)
        rescue
          Game.info({exception: $!, backtrace: $!.backtrace}, true)
        end
      end

      # Human appearance
      if @config['human']
        @details = Players::Appearance.random_appearance
      end

      # Named
      if @config['named']
        @name = Game.fake(:first_name)
      end

      # Initial attachments
      if attach = @config['set_attachments']
        slots = attach.inject({}){ |hash, attachment|
          hash[@config.slots.index(attachment[0])] = @config.attachments.index(attachment[1])
          hash
        }
        set_details 'sl' => slots
      end

      initialize_entity
    end

    def player?
      false
    end

    def npc?
      true
    end

    def servant?
      !!@servant
    end

    def grant_xp?(type)
      false
    end

    def after_add
      # Create new character if supposed to have one but do not (e.g., spawned, not loaded)
      if @config['character'] && !@character
        initialize_character
      end
    end

    def initialize_character
      @character = Character.new(
        zone_id: @zone.id,
        ilk: @ilk,
        position: @position.to_a,
        name: @name,
        metadata: @metadata,
        created_at: Time.now
      )
      @character.ephemeral = @ephemeral
      @character.entity = self
      @character.save
    end

    def behave!
      begin
        delta_time = 0
        if Ecosystem.time > @last_behaved_at + @behave_interval
          delta_time = Ecosystem.time - @last_behaved_at
          @last_behaved_at = Ecosystem.time
        else
          return false
        end

        process_effects delta_time unless zone.static?

        if @die_at && Ecosystem.time > @die_at
          die! and return
        end

        # Move if it is time
        if Ecosystem.time >= @last_moved_at + 1.0 / self.speed
          @last_moved_at = Ecosystem.time
          @blocked = {} # Reset cached blocked? blocks
          @velocity.zero!

          @behavior.tick

          # Move if requested
          unless @move.zero?
            self.position.move! @move
            check_block_position_changed

            # Update position and, if speed variance is defined, speed
            if @speed_variance && Ecosystem.time > @next_speed_variance_at
              @speed = @base_speed * @speed_variance.random
              @next_speed_variance_at = Ecosystem.time + (2..3).random.seconds
            end
            @velocity = @move * @speed

            @move.zero!
            @chunk_index = @zone.chunk_index(@position.x, @position.y)
          end

          # Set active and immediate chunk time
          if zone.position_active?(self.position)
            @last_in_active_chunk_at = Ecosystem.time

            if @zone.position_immediate?(self.position)
              @last_in_immediate_chunk_at = Ecosystem.time
            end
          end
        end
      rescue
        Game.info({exception: $!, backtrace: $!.backtrace}, true)
      end

      true
    end

    def interact(player, type = :interact, params = nil)
      if @behavior
        @behavior.react type, [player, params]
      end
    end

    def damageable?
      true
    end

    def critical_hit_rate
      1.0
    end

    def health=(val)
      @health = [val, @config.health].min # Don't let health to go over max

      if @health <= 0
        set_details '!' => 'v'
      end
    end

    def set_details(hash)
      @details ||= {}
      @details.merge! hash
    end

    def group
      @config.group
    end

    def grounded?(diagonal = 0)
      blocked?(0, 1) || (diagonal != 0 and blocked?(diagonal, 1))
    end

    def wet?(x = 0, y = 0)
      x = self.position.x + x
      y = self.position.y + y

      if zone.in_bounds?(x, y)
        liquid = zone.peek(x, y, LIQUID)
        return liquid.first > 0 && liquid.last > 0
      else
        false
      end
    end

    def can_be_targeted?(entity = nil)
      true
    end

    def blocked_perf(x = 0, y = 0)
      times = 1

      new_blocked_result = nil
      old_blocked_result = nil

      newbench = Benchmark.measure do
        times.times { new_blocked_result = @zone.kernel.blocked?(self.position.x, self.position.y, x, y) }
      end

      oldbench = Benchmark.measure do
        times.times { old_blocked_result = old_blocked(x, y) }
      end

      puts "old: #{oldbench.real}, new: #{newbench.real} #{new_blocked_result == old_blocked_result ? 'MATCH' : 'MISMATCH'}"
      new_blocked_result
    end

    def blocked?(x = 0, y = 0)
      unless b = @blocked[[x, y]]
        b = @blocked[[x, y]] = @zone.blocked?(self.position.x, self.position.y, x, y)
      end
      b
    end

    def in_bounds?(x = 0, y = 0)
      zone.in_bounds?(position.x + x, position.y + y)
    end

    def climber?
      true
    end

    def moves?
      @config.move != false
    end

    def placeoverable?
      @size.x == 1 && @size.y == 1
    end

    def behavior_benchmark(behavior, time)
      zone.increment_benchmark behavior.key, time
    end



    # ===== Configuration ===== #

    def process_config(cfg)
      # Get configuration based on string / hash / array of components
      case cfg
      when Fixnum
        process_config Game.entity_by_code(cfg)
      when String
        process_config Game.entity(cfg)

      when Hash
        # Component-based entities need to get some random components as well
        if cfg.components
          selected_components = cfg.components.inject({}) do |memo, item|
            key = item.first
            options = item.last

            # If there are excluding components, remove any that match (e.g., propeller should exclude any headgear)
            if cfg.exclude_components && excl = cfg.exclude_components.keys.find{ |excl| memo.values.include?(excl) }
              options = options.reject{ |o| o && o.match(/#{cfg.exclude_components[excl]}/) }
            end

            sel = options.random
            memo[key] = sel unless sel.nil?
            memo
          end
          process_config [cfg.name, selected_components]
        else
          @config = cfg
        end

      when Array
        base = Game.entity(cfg.first)
        raise "Invalid base component" unless base
        merged_config = base.dup

        components = cfg.last
        component_codes = []
        raise "Invalid components" unless components.is_a?(Hash)

        # Process components
        components.each_pair do |key, name|
          # Ensure component is allowed by base
          raise "Component #{name} not allowed as #{key}" unless base.components[key].include?(name)

          component_config = Game.entity(name)
          raise "Component #{name} does not exist" unless component_config

          # Merge config into base
          merged_config.deeper_merge! component_config

          component_codes << component_config.code
        end

        # Handle arrays that should be replaced, not concatenated (default that occurs with deeper_merge)
        merged_config.damage.slice! 0, merged_config.damage.size - 2 if merged_config.damage

        @config = merged_config
        @config.code = base.code # Use base code
        @details = { 'C' => component_codes }
      end
    end
  end
end
