module Achievements
  class TradingAchievement < BaseAchievement

    def check(player)
      progress_all player
    end

  end
end