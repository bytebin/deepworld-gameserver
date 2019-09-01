module Players
  module Cold

    def set_default_freeze
      if @zone.biome == 'arctic'
        @freeze ||= 0
      else
        @freeze = nil
      end
    end

    def warm(should_notify = true)
      @freeze = 0 if @zone.biome == 'arctic'
      send_freeze_message

      alert "Ahh, toasty warmth." if should_notify
    end

    def apply_freeze(delta)
      if alive? && @freeze
        if @freeze < 1.0
          @freeze = (@freeze + delta / freeze_period).clamp(0, 1.0)
          send_freeze_message
        else
          damage! 0.25, 'cold'
        end
      end
    end

    def freeze_period
      sk = adjusted_skill('survival')
      (sk < 5 ? 3.lerp(10.0, (sk-1) / 3.0) : 24*60).minutes
    end

    def send_freeze_message
      queue_message StatMessage.new([:freeze, @freeze.to_f.clamp(0, 1.0)])
    end

  end
end