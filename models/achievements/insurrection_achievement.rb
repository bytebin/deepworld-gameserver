module Achievements
  class InsurrectionAchievement < BaseAchievement

    def check(player)
      progress player, @achievements.values, 1
    end
  end
end