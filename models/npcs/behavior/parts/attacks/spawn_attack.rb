module Behavior
  class SpawnAttack < Rubyhave::Behavior

    def on_initialize
      @start_at = Time.now + (@options['delay'] || 0)
      @range = @options['range']
      @burst = @options['burst']
      @speed = @options['speed'] || 8
      @frequency = @options['frequency']
      @spawn_entity = @options['entity']
      @animation = @options['animation']
      @slot = @options['slot'] ? [*@options['slot']] : nil
      @npc = @options['npc']
      @max = @options['max'] || 1
    end

    def behave(params = {})
      # NPC entity (creatures, etc.)
      if @npc
        pos = (entity.position + (entity.size * 0.5)).fixed
        if spawn = zone.spawn_entity(@spawn_entity, pos.x, pos.y, false, true)
          spawn.owner_id = entity.entity_id
          spawn.spawned = true
          entity.spawns << spawn.entity_id
        end

      # Client entity (bullet, etc.)
      else
        spawn = Npcs::Npc.new(@spawn_entity, zone, entity.position)
        spawn.set_details({ '<' => entity.entity_id, '>' => @target.entity_id, '*' => true, 's' => @speed})
        spawn.set_details('#' => @burst) if @burst

        if @slot
          if slot_idx = entity.config.slots.index{ |sl| sl == @slot.random }
            spawn.set_details('sl' => [slot_idx, 5, 5])
          end
        end

        zone.add_client_entity spawn, entity
      end

      if @animation
        entity.animation = @animation
        Rubyhave::SUCCESS
      end
    end

    def can_behave?(params = {})
      Ecosystem.time > @start_at &&
      (@target = get(:target)) &&
      !behaved_within?(1.0 / @frequency) &&
      target_in_range?(@target) &&
      (!@npc || entity.spawns.size < @max)
    end

    def target_in_range?(target)
      @range.nil? || Math.within_range?(entity.position, target.position, @range)
    end

    def react(message, params)
      if message == :anger && !@angry
        @frequency += 0.25 if @frequency
        @range = (@range * 1.2).to_i if @range
        @speed = (@speed * 1.2).to_i if @speed
        @angry = true
      end
    end
  end
end

