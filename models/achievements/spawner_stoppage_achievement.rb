module Achievements
  class SpawnerStoppageAchievement < BaseAchievement

    def check(player, group)
      return if player.zone.biome == 'deep' && player.zone.acidity > 0.01

      achievements = @achievements.values.select{ |ach| ach.group == group }
      progress player, achievements, 1
    end

  end
end
