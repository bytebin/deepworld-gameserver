module Dynamics
  class Happenings

    def initialize(zone)
      @zone = zone

      @invasion = Invasion.new(zone)
    end

    def step!(delta)
      begin
        if hap = Game.happening("invasion")
          if @zone.players_count && @zone.players_count > 0
            @invasion.base_interval = hap["interval"] || 10.minutes
            @invasion.step
          end
        end
      rescue
        Game.info({exception: $!, backtrace: $!.backtrace}, true)
      end
    end


    class Happening

      attr_accessor :base_interval

      def initialize(zone)
        @zone = zone
        @base_interval = 10.minutes
        @last_event_at = Time.now
      end

      def interval
        @base_interval / (@zone.players_count || 1)
      end

      def step
        if Time.now > @last_event_at + interval
          event!
          @last_event_at = Time.now
        end
      end

      def event!
      end

    end

    class Invasion < Happening

      def event!
        @zone.invasion.invade! @zone.players.random
      end

    end

  end
end
