module Achievements
  class RaiderAchievement < BaseAchievement

    def check(player)
      progress player, @achievements.values, 1
    end
  end
end