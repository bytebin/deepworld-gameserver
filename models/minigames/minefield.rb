module Minigames
  class Minigame < Base
    include Leaderboard

    def max_deaths
      3
    end

    def after_disqualification(player, reason)
      player.suppress! :mining
    end

  end
end
