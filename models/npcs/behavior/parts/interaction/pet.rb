module Behavior
  class Pet < Rubyhave::Behavior

    def on_initialize
      @last_petted_at = Time.now
    end

    # React

    def react(message, params)
      case message
      when :interact
        return unless Ecosystem.time > @last_petted_at + 2.seconds
        @last_petted_at = Ecosystem.time
        player = params.first

        x = @entity.position.x * Entity::POS_MULTIPLIER
        y = @entity.position.y * Entity::POS_MULTIPLIER
        player.zone.queue_message EffectMessage.new(x, y, 'terrapus purr', 1)

      end
    end

  end
end
