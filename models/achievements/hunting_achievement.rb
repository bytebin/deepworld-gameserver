module Achievements
  class HuntingAchievement < BaseAchievement

    def check(player, entity)
      achievements = @achievements.values.select{ |ach| ach.group == entity.group }
      progress player, achievements, 1
    end
  end
end