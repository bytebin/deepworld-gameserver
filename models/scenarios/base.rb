module Scenarios
  class Base

    def initialize(zone)
      @zone = zone
    end

    def load
    end

    def update_player_configuration(player, cfg)
    end

    def validate_command(command)
    end

    def step(delta_time)
    end

    def player_event(player, event, data)
    end

    def show_in_recent?
      true
    end

  end
end
