module Biomes
  class Space

    def initialize(zone)
      @zone = zone
      @supernova = Supernova.new(zone)
    end

    def load
      @zone.acidity = 0
    end

    def step(delta_time)
      @supernova.step
      if @supernova.done?
        @supernova = Supernova.new(@zone)
      end
    end

    class Supernova

      def initialize(zone)
        @zone = zone
        @show_at = Time.now + (180..360).random.seconds
        @damage_delay = 5.seconds
        @damage_at = @show_at + @damage_delay
      end

      def step
        if !@shown && Time.now > @show_at
          @zone.queue_message EventMessage.new("supernova", @damage_delay)
          @shown = true
        end

        if !@damaged && Time.now > @damage_at
          @zone.players.each do |pl|
            if @zone.peek(pl.position.x.to_i, pl.position.y.to_i, BASE)[0] == 0
              pl.damage! 9999
              pl.send_hint "supernova"
            end
          end
          @damaged = true
        end
      end

      def done?
        @damaged
      end

    end

  end
end
