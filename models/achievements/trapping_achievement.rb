module Achievements
  class TrappingAchievement < BaseAchievement

    def check(player, command)
      if command.item.group == 'cage'
        x = command.x
        y = command.y
        zone = player.zone

        # See if there's a trappable entity
        if entity = zone.npcs_at_position(Vector2[x, y]).find{ |npc| npc.config.trappable }
          return if entity.spawned

          # Check if the cage is surrounded
          caged = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]].all? do |surround|
            x2 = x + surround[0]
            y2 = y + surround[1]
            zone.in_bounds?(x2, y2) && Game.item(zone.peek(x2, y2, FRONT)[0]).whole
          end

          if caged
            zone.update_block nil, x, y, FRONT, Game.item_code('ground/fur'), rand(3) + 1
            entity.die! player
            progress_all player
            player.add_xp :trapping
          end
        end
      end
    end
  end
end