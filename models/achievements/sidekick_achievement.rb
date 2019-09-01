module Achievements
  class SidekickAchievement < BaseAchievement

    def check(player)
      progress player, @achievements.values, 1
    end
  end
end