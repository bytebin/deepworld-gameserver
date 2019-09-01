module Players
  module Suppression

    def suppress_guns?
      @suppress_guns || zone.suppress_guns
    end

    def suppress_mining?
      @suppress_mining || zone.suppress_mining
    end

    def suppress!(type, is_suppressed = true)
      case type
      when :flight
        @suppress_flight = is_suppressed
        queue_message ZoneStatusMessage.new('suppress_flight' => is_suppressed)
      when :guns
        @suppress_guns = is_suppressed
        queue_message ZoneStatusMessage.new('suppress_guns' => is_suppressed)
      when :mining
        @suppress_mining = is_suppressed
        queue_message ZoneStatusMessage.new('suppress_mining' => is_suppressed)
      end
    end

  end
end