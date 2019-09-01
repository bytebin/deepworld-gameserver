module Achievements
  class KillerAchievement < BaseAchievement

    def check(player)
      progress_all player
    end

  end
end