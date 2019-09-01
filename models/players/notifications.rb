module Players
  module Notifications

    def notify_list(sections)
      if v2?
        notify({ sections: sections }, 12)
      end
    end

    def notify_error(msg)
      if Time.now > @last_error_notification_at + 2.second
        alert msg
        @last_error_notification_at = Time.now
      end
    end

    def alert(msg)
      notify msg, 1
    end

    def alert_multi(title, text = nil, image = nil)
      msg = { 't' => title }
      msg['t2'] = text if text
      msg['i'] = image if image
      notify msg, 6
    end

    def alert_profile(title, desc)
      if v3? || Deepworld::Env.test?
        alert "<color=#ffd95f>#{title}</color>\n#{desc}"
      else
        delay = @next_profile_alert ? @next_profile_alert - Time.now : 0
        @next_profile_alert = [@next_profile_alert, Time.now].compact.max + 7.seconds

        EM.add_timer(delay) do
          notify({title: title, desc: desc}, 16)
        end
      end
    end

    def emote(msg)
      notify msg, 3
    end

  end
end
