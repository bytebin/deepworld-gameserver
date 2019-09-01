module Achievements
  class ArchitectAchievement < BaseAchievement

    def check(player)
      progress_all player
    end

  end
end