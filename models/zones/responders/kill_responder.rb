module Zones
  class KillResponder

    def initialize(zone)
      @zone = zone
    end

    def player_event(player, entity)
      # Teleport in brains if player streak kills a lot of them
      if entity.config.respond_to?(:vengeance) && entity.config.vengeance
        streak = player.mobs_killed_streak[entity.code.to_s] || 0
        entity.config.vengeance.each do |possible_vengeance|
          if streak >= possible_vengeance[0] && rand < possible_vengeance[2]
            EM.add_timer(2 + rand(5)) do
              vengeance! player, possible_vengeance
            end
          end
        end
      end
    end

    def vengeance!(player, config)
      # Try a few times to find a non-blocked spot by player
      10.times do
        on_top = rand < 0.05
        x = player.position.x + (on_top ? 0 : (-4..4).random.to_i)
        y = player.position.y + (on_top ? -1 : (-3..3).random.to_i)
        unless @zone.blocked?(x, y)
          if ent = @zone.spawn_entity(config[1], x, y, nil, true)
            ent.behavior.react :anger, nil
          end
          return
        end
      end
    end

  end
end
