module Achievements
  class MiningAchievement < BaseAchievement

    def check(player, command)
      achievements = @achievements.values.select{ |ach| ach.group == command.item.group }
      progress player, achievements, 1
    end

  end
end