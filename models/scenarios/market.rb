module Scenarios
  class Market < Base

    def load
      @zone.suppress_turrets = true
      @zone.suppress_spawners = true
    end

  end
end