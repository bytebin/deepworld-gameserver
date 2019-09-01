module Zones
  module Explosions

    def explode(position, radius, triggerer = nil, destruction = true, base_damage = 5, damage_types = ['crushing', 'fire'], effect = 'bomb', selectively_damage_ilks = nil, damage_modifiers = nil)
      player = triggerer.is_a?(Player) ? triggerer : triggerer.try(:player)

      benchmark = Benchmark.measure do
        # Send effect
        players.each do |pl|
          msg_effect = pl.v3? && effect == 'bomb' && radius > 6 ? 'bomb-large' : effect
          queue_message EffectMessage.new((position.x + 0.5) * Entity::POS_MULTIPLIER, (position.y + 0.5) * Entity::POS_MULTIPLIER, msg_effect, pl.v3? ? 1 : radius)
        end

        position = position.fixed

        # Get entities in range
        all_entities = entities_in_range(position, radius)

        # Get all protectors in range
        protectors = protectors_in_range(position, radius)

        # Perform raycasts (*not cpu intensive)
        raycast_count = radius * 5 + rand(5)
        raycasts = (0..raycast_count-1).map do |r|
          angle = r * (2*3.1415 / raycast_count)
          ray = Vector2[Math.sin(angle.to_f), Math.cos(angle.to_f)]
          raypath(position, ray_destination(position, ray, radius), false, true, true)
        end

        # Iterate through raycasts and damage blocks
        destroys = []
        affected_indexes = []
        checked = {}
        raycasts.each do |raycast|
          raycast.each_with_index do |block, distance|
            pos = Vector2[block[0], block[1]]
            key = (pos.y * @size.x + pos.x) * 10 + FRONT

            # Get item data
            front_data = block[2][3, 2]
            front_item = Game.item(front_data[0])
            back_data = block[2][1, 2]
            back_item = Game.item(back_data[0])

            # Determine power
            power = radius - distance

            # Only destroy if power is greater than distance and block isn't protected
            if front_item.code == 0 || (!front_item.invulnerable && power > (front_item.toughness || 0))
              # Don't re-update blocks
              unless checked[key]
                checked[key] = true
                affected_indexes << block_index(pos.x, pos.y)

                if destruction && !front_item.field && !block_protected?(pos, player, false, protectors_in_range(pos, 0, protectors))
                  # Front: only affect block if non-air, non-special-item
                  if front_item.code > 0 && (!front_item.meta || get_meta_block(pos.x, pos.y).try(:special_item?) != true)
                    # Ding karma for block & queue destruction
                    player.check_karma pos.x, pos.y, FRONT, front_item.code if player
                    destroys << [nil, pos.x, pos.y, FRONT, 0]
                  end

                  # Back: only affect if non-air
                  if back_item.code > 0
                    player.check_karma pos.x, pos.y, BACK, back_item.code if player
                    destroys << [nil, pos.x, pos.y, BACK, 0]
                  end
                end
              end
            else
              break
            end
          end
        end

        # Damage entities if they were hit by any raycasts
        all_entities.each do |entity|
          next if selectively_damage_ilks && !selectively_damage_ilks.include?(entity.ilk)

          entity_block_index = block_index(entity.position.x.round.to_i, entity.position.y.round.to_i)
          if affected_indexes.include?(entity_block_index)

            total_damage = base_damage - (entity.position - position).magnitude

            # Deal equal amounts of damage for damage types
            damage_types.each do |d|
              attack = Entities::Effect::Attack.new(triggerer, entity, nil, damage: [d, total_damage / damage_types.size], modifiers: damage_modifiers, explosive: true)
              attack.process 1.0
            end
          end
        end

        # Always kill bomb itself!
        bomb_peek = peek(position.x, position.y, FRONT)
        update_block nil, position.x, position.y, FRONT, 0 if Game.item(bomb_peek[0]).fieldable == false
        update_block nil, position.x, position.y, BACK, 0 if destruction && !block_protected?(position, player, false, protectors) # Back tile might be protected

        # Order raycasted blocks by distance and update blocks
        if destruction
          destroys.sort_by!{ |b| Math.hypot b[1] - position.x, b[2] - position.y }
          destroys.each do |b|
            update_block *b
          end
        end
      end
    end

    def explode_liquid(position, liquid, range = 6)
      item = Game.item_code(liquid)

      (position.x-range..position.x+range).each do |x|
        (position.y-range..position.y+range).each do |y|
          if in_bounds?(x, y)
            if ZoneKernel::Util.within_range?(x, y, position.x, position.y, range)
              update_block nil, x, y, LIQUID, item, 5 unless blocked?(x, y)
            end
          end
        end
      end
    end

  end
end