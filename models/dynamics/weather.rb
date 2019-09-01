module Dynamics
  class Weather

    TIME_MULTIPLIER = 1.0
    DAMAGE_INTERVAL = 1.0

    attr_accessor :rain, :cold, :heat

    def initialize(zone)
      @zone = zone
      @rain = Rain.new(Rain.random_dry_duration * 0.4, 0)
      @cold = Cold.new(@zone) if @zone.biome == 'arctic'
      @heat = Heat.new(@zone)
      @last_damage_at = Time.now
    end

    def step!(delta)
      # Start up new rain period if the current one is done
      if @rain.complete?
        @zone.rain_complete if @rain.wet?
        @rain = Rain.random_rain(@rain.dry? ? :wet : :dry)
      end

      # Update zone status (slope up as new rain takes effect)
      lerp = 0.02.lerp(0.1, @rain.elapsed)
      @zone.wind = @zone.wind.lerp(@rain.power, delta * lerp)
      @zone.cloud_cover = @zone.cloud_cover.lerp(@rain.power, delta * lerp)
      @zone.precipitation = @zone.precipitation.lerp(@rain.power, delta * lerp)

      # Raining
      if @rain.wet?
        # Cause acid rain damage (disabled for now - client only)
        # if Time.now > @last_damage_at + DAMAGE_INTERVAL
        #   if @zone.precipitation > 0.1
        #     @zone.players.each do |player|
        #       player_x_floor = player.position.x.floor
        #       player_x_frac = player.position.x - player_x_floor
        #       player_x = player_x_frac > 0.75 ? player_x_floor + 1 : player_x_frac < 0.25 ? player_x_floor - 1 : player_x_floor
        #       if @zone.light.light_at(player_x, player.position.y.floor)
        #         player.damage! 0.5 * @zone.acidity, 'acid'
        #       end
        #     end
        #   end

        #   @last_damage_at = Time.now
        # end

        # TODO: Pool up liquidz
      end

      @cold.step delta if @cold
      @heat.step delta if @heat
    end



    class Rain
      attr_accessor :duration, :power

      def initialize(duration, power)
        @start = Time.now
        @duration = duration
        @power = power
      end

      def active?
        !complete?
      end

      def complete?
        Time.now > @start + @duration
      end

      def elapsed
        (Time.now - @start) / @duration
      end

      def dry?
        power == 0
      end

      def wet?
        power > 0
      end

      def to_s
        "<Rain duration: #{@duration.to_i}, elapsed: #{'%.2f' % self.elapsed}, power: #{@power}>"
      end

      def self.random_wet_duration
        (2.5..4).random.minutes * TIME_MULTIPLIER
      end

      def self.random_dry_duration
        (12..17).random.minutes * TIME_MULTIPLIER
      end

      def self.random_rain(type)
        if type == :wet
          Rain.new(random_wet_duration, (0.33..1.0).random)
        else
          Rain.new(random_dry_duration, 0)
        end
      end
    end


    # Apply cold damage to players unless they warm themselves

    class Cold
      def initialize(zone)
        @zone = zone
        @freeze_duration = 0
      end

      def step(delta)
        # Accumulate delta and cause freezing less often
        @freeze_duration += delta
        if @freeze_duration > 1.0
          @zone.players.each do |player|
            player.apply_freeze @freeze_duration
            @freeze_duration = 0
          end
        end
      end
    end

    # Apply heat damage to players unless they have water to drink

    class Heat
      def initialize(zone)
        @zone = zone
      end

      def step(delta)
        @zone.players.each{ |player| player.apply_heat delta }
      end
    end

  end
end