module Items
  class Quipper < Base

    def use(params = {})
      return if zone.time_gates[:quipper] && Time.now < zone.time_gates[:quipper]

      if fake = Game.fake(@item.use.quipper)
        @zone.queue_message EffectMessage.new((@position.x + 0.5) * Entity::POS_MULTIPLIER, (@position.y - 0.5) * Entity::POS_MULTIPLIER, 'emote', fake)
        @zone.time_gates[:quipper] = Time.now + 0.5
      end
    end

  end
end
