module Scenarios
  class Minefield < Base

    def load
      @zone.suppress_guns = true
      @zone.pvp = true
      @minigame = @zone.start_minigame(:minefield)
    end

    def player_event(player, event, data)
      # score_player_event player, event, data
    end

  end
end