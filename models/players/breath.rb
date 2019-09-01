module Players
  module Breath

    def check_liquid
      # Check liquid block for suffocation / damage
      if @position && @position.y > 0
        liquid_peek = zone.peek(@position.x, @position.y - 1, LIQUID)
        if liquid_peek[1] > 2 and item = Game.item(liquid_peek[0])
          @submerged_item = item
        else
          @submerged_item = nil
        end
      end
    end

    def apply_breath(delta, air = false)
      if inv.accessory_with_use('breath')
        @breath = 1.0
      elsif air
        @breath = (@breath + delta).clamp(0, 1.0)
      else
        @breath = (@breath - (delta / breath_period)).clamp(0, 1.0)
      end

      if !@last_breath_message_at || Time.now > @last_breath_message_at + 1.second
        send_breath_message
        damage! 0.5, 'suffocation' if @breath == 0
        @last_breath_message_at = Time.now
      end
    end

    def breath_period
      15.seconds
    end

    def send_breath_message
      if @last_breath_message != @breath
        queue_message StatMessage.new([:breath, @breath])
        @last_breath_message = @breath
      end
    end

  end
end
