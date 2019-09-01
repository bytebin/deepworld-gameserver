module Achievements
  class UndertakerAchievement < BaseAchievement

    def check(player, command)
      if command.item.group == 'gravestone'
        x = command.x
        y = command.y
        zone = player.zone

        # ===== Check that conditions are met (gravestone above ground, skeleton below ground and surrounded by earth) =====
        return unless zone.size.y > y + 2 # Must have room vertically
        return unless x > 0 and x < zone.size.x - 1 # Must have room horizontally

        return unless zone.peek(x, y, BASE)[0] == 0 # Gravestone must be aboveground
        return unless zone.peek(x, y + 1, BASE)[0] == 2 # Beneath gravestone must be belowground
        return unless zone.peek(x, y + 1, FRONT)[0] == Game.item_code('rubble/skeleton') # Skeleton must be beneath gravestone

        # Skeleton must be surrounded by dirt
        earth = Game.item_code('ground/earth')
        return unless [[x - 1, y + 1], [x, y + 2], [x + 1, y + 2], [x + 2, y + 1]].all?{ |b| zone.peek(b.first, b.last, FRONT)[0] == earth }

        # Convert skeleton to earth and cause FX
        zone.update_block nil, x, y + 1, FRONT, earth
        zone.update_block nil, x + 1, y + 1, FRONT, earth
        ['sparkle up', 'expiate'].each do |fx|
          zone.queue_message EffectMessage.new((x + 0.5) * Entity::POS_MULTIPLIER, (y + 0.5) * Entity::POS_MULTIPLIER, fx, 20)
        end
        zone.spawn_entity 'ghost', x, y, nil, false if rand < 0.3333

        progress_all player
        player.add_xp :undertaking
      end
    end
  end
end