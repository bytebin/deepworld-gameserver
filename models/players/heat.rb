module Players
  module Heat

    def apply_heat(delta)
      return unless thirsts?

      direction = @zone.biome == 'desert' ? 1.0 : -1.0 # Desert biomes add thirst, everywhere else subtracts it
      @thirst = (@thirst + (direction * delta * (1.0 / thirst_period))).clamp(0, 1.0)
      send_thirst_message if !@last_thirst_message || Time.now > @last_thirst_message + 1.0

      if @thirst >= 1.0
        water_jar = Game.item_code('containers/jar-water')

        if @inv.contains?(water_jar)
          @inv.remove water_jar, 1, true
          notify '-1 Jar of Water', 4
          @thirst = 0
        else
          @next_thirst_damage_at ||= Time.now - 1.second
          if Time.now > @next_thirst_damage_at
            damage! 0.25, 'fire'
            @next_thirst_damage_at = Time.now + 3.seconds
          end
        end
      elsif @thirst > 0.5
        send_hint 'desert-heat'
      end
    end

    def thirst_period
      sk = adjusted_skill('survival')
      5.lerp(10.0, (sk-1) / 6.0).minutes
    end

    def thirsts?
      adjusted_skill('survival') < 8 && zone.acidity > 0.05
    end

    def send_thirst_message
      queue_message StatMessage.new([:thirst, @thirst.to_f.clamp(0, 1.0)])
      @last_thirst_message = Time.now
    end

  end
end