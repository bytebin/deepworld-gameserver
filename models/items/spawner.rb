module Items
  class Spawner < Base

    def use(params = {})
      return if @zone.suppress_spawners

      # If a spawned entity is already out there, kill it first
      kill_existing_entity

      # Get entity type
      selected_entity = @meta['e']
      if entity_code = @item.use.spawn[selected_entity]
        entity = @zone.spawn_entity(entity_code, @position.x, @position.y, false, true)
        entity.spawned = @meta
        @meta['eid'] = entity.entity_id
      end
    end

    def validate(params = {})
      require_interval(5)
    end

    def destroy!
      kill_existing_entity
    end


    private

    def kill_existing_entity
      if @meta['eid']
        if existing_entity = @zone.entities[@meta['eid']]
          if existing_entity.alive?
            @zone.queue_message EffectMessage.new((existing_entity.position.x + 0.5) * Entity::POS_MULTIPLIER, (existing_entity.position.y + 0.5) * Entity::POS_MULTIPLIER, 'bomb-teleport', 4)
            existing_entity.die!
          end
        end
      end
    end

  end
end