module Players
  module Happenings

    def alert_happenings
      @alerted_happenings ||= []

      Game.happenings.each_pair do |key, hap|
        if message = hap["message"]
          if !hap["expire_at"] || Time.now < hap["expire_at"]
            key = "#{key}#{hap["expire_at"]}"
            unless @alerted_happenings.include?(key)
              period = (hap["expire_at"] - Time.now).to_period(false, false)
              alert_profile message[0], message[1].gsub(/\@/, period)
              @alerted_happenings << key
              return
            end
          end
        end
      end
    end
  end
end
