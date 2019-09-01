module Achievements
  class PositionAchievement < BaseAchievement

    def check(player)
      return if player.position.nil?

      self.remaining_achievements(player).each_pair do |title, config|

        if config.top
          y = config.top
        elsif config.bottom
          y = player.zone.size.y - config.bottom
        end

        if config.left
          x = config.left
        elsif config.right
          x = player.zone.size.x - config.right
        end

        if (x.nil? || ((player.position.x - x).abs < 1)) && (y.nil? || ((player.position.y - y).abs < 1))
          player.add_achievement title
        end
      end
    end

  end
end
