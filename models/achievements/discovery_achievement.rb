module Achievements
  class DiscoveryAchievement < BaseAchievement

    def check(player, item)
      return unless player and item
      achievements = @achievements.values.select do |ach|
        ach.item == item.id or ach.group == item.group
      end

      progress player, achievements, 1
    end

  end
end