module Achievements
  class ExploringAchievement < BaseAchievement
    
    def check(player)
      progress_all player, 1
    end

  end
end
