module Players
  module Visibility

    def visibility_setting
      (@settings || {})['visibility'] || 0
    end

    def locateable_to_player?(player)
      return false unless position && player.position

      distance = (position - player.position).magnitude

      case self.visibility_setting
      when 0
        return true if distance < visible_distance || player.follows?(self)
      when 1
        return true if distance <= hidden_visible_distance || (player.follows?(self) && follows?(player))
      when 2
        return true if distance <= hidden_visible_distance
      end

      false
    end

    def visible_to_player?(player)
      case self.visibility_setting
      when 0
        true
      when 1
        player.followed?(self)
      when 2
        false
      end
    end

    def visible_distance
      250
    end

    def hidden_visible_distance
      100
    end

    def active_recently?
      last_active_at && last_active_at > Time.now - 2.minutes
    end

    def visibility_description(other_player)
      if visible_to_player?(other_player)
        if active_recently?
          "<color=33aa33>Online</color>\nCurrently in #{zone_name}."
        else
          "Offline"
        end
      else
        nil
      end
    end

    def send_players_online_message
      if v3?
        begin
          if Game.players_online
            onlines = Game.players_online.inject({}) do |hash, pl|
              visible = pl[1].vis == 0 || (pl[1].vis == 1 && @followers.include?(pl[1].id))
              hash[pl[1].name] = true if visible
              hash
            end
            queue_message PlayerOnlineMessage.new(onlines)
          end
        rescue
          p "[Visibility] #{$!}"
        end
      end
    end

  end
end