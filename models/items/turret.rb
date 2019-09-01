module Items
  class Turret < Base

    def use(params = {})
      if entity = Game.entity(@item.spawn)
        mod = @zone.peek(@position.x, @position.y, FRONT)[1]
        if direction = { 0 => Vector2[0, -1], 1 => Vector2[1, 0], 2 => Vector2[0, 1], 3 => Vector2[-1, 0] }[mod]
          origin = @position + direction
          target = origin + (direction * 10)
          target = @zone.raycast(origin, target) || target.to_a

          # Spawn
          spawn = Npcs::Npc.new(entity, @zone, origin)
          spawn.set_details({ '<' => origin, '>' => target, '*' => true, 's' => @item.speed || 10})
          spawn.set_details('#' => @item.burst) if @item.burst

          zone.add_client_entity spawn, @player || @entity
        end
      end
    end

    def validate(params = {})
      require_interval(1)
    end
  end
end