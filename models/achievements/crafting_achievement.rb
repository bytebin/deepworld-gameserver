module Achievements
  class CraftingAchievement < BaseAchievement

    def check(player, command)
      progress_all player
    end

  end
end