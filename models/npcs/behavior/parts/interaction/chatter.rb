module Behavior
  class Chatter < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @started_at = Time.now - 1.day
      @last_chatted_at = @started_at
      @entities_chatted_at = {}
    end

    def behave
      # Emote message if it is time
      if @next_message && Ecosystem.time > @next_message_at
        entity.emote @next_message
        @next_message = nil
      end

      # Only chat every so often
      if Ecosystem.time < @last_chatted_at + 6.seconds
        return Rubyhave::SUCCESS

      else
        # Find a random target to chat with
        if other = random_player(3)
          # Only chat if it's been a while for this specific target
          if time_since_chatted_at(other) > 60.seconds
            chat_at other
            entity.animation = 0
            return Rubyhave::SUCCESS
          end
        end
      end

      return Rubyhave::FAILURE
    end

    def chat_at(other)
      # Messages are scheduled in the future so entity has time to stop moving
      @next_message = Game.fake(:salutation)
      @next_message_at = Ecosystem.time + 1.second

      entity.direction = entity.position.x > other.position.x ? -1 : 1
      @entities_chatted_at[other.entity_id] = Ecosystem.time
      @last_chatted_at = Ecosystem.time
    end

    def time_since_chatted_at(other)
      Ecosystem.time - (@entities_chatted_at[other.entity_id] || @started_at)
    end

    def can_behave?
      true
    end
  end
end
