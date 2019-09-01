module Achievements
  class DeliveranceAchievement < BaseAchievement

    def check(player, count)
      progress_all player, count
    end

  end
end