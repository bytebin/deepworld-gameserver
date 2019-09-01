module Achievements
  class VotingAchievement < BaseAchievement

    def check(player)
      progress_all player
    end

  end
end