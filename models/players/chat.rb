module Players
  module Chat

    def chat!(text, recipient = nil, type = 'c', obscene = false)
      text.gsub! /[^\s]/, '.' if muted # Muffle text if muted
      msg = ChatMessage.new(entity_id, text, type)

      # Don't send if recently chatted same thing
      earliest_repeat_time = Time.now - 10.seconds
      if @recent_chats.any?{ |ch| ch[0] > earliest_repeat_time && ch[1] == text }
        alert "You've said that recently. Please don't spam chat."

      else
        # Always send message to self
        queue_message msg

        # Send to recipients who haven't muted player (unless muted or in tutorial)
        unless muted || zone.tutorial?
          recipients = recipient ? [recipient] : zone.players - [self]
          recipients.each do |other|
            # Only send if not muted by this player
            other.queue_message msg unless other.has_muted?(self)
          end
        end

        # Damage player if message is obscene
        track_obscenity! if obscene
        zone.chat(self, text, recipient)

        @recent_chats.shift if @recent_chats.size > 20
        @recent_chats << [Time.now, text]
      end
    end

    def mute!(other_player, duration = nil, should_notify = false)
      if should_notify && !mutings[other_player.id.to_s] && other_player.connection
        other_player.alert "#{name} has muted you#{' for ' + duration.to_s + ' minute(s)' if duration}."
      end

      update({"mutings.#{other_player.id}" => duration ? Time.now.to_i + (duration*60) : 0 })
      alert "#{other_player.name} has been muted#{' for ' + duration.to_s + ' minute(s)' if duration}."
    end

    def mute_all!(duration = nil)
      update({"mutings.all" => duration ? Time.now.to_i + (duration*60) : 0})
      alert "All chats muted."
    end

    def has_muted?(player)
      (mutings[player.id.to_s] && (mutings[player.id.to_s] == 0 || Time.now.to_i < mutings[player.id.to_s])) || has_muted_all?
    end

    def has_muted_all?
      mutings['all'] && (mutings['all'] == 0 || Time.now.to_i < mutings['all'])
    end

    def unmute_all!
      update({"mutings.all" => -1})
      alert "All chats unmuted."
    end

    def unmute!(other_player)
      other_player_name = other_player.try(:name) || 'Player'

      if mutings[other_player.id.to_s]
        update({"mutings.#{other_player.id}" => -1}) do
          alert "#{other_player_name} has been unmuted."
        end
      else
        alert "#{other_player_name} is not muted."
      end
    end

  end
end