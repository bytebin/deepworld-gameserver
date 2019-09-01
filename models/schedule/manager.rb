module Schedule
  class Manager

    def initialize
      @events = []
    end

    def add(params)
      @events << params.stringify_keys
      puts "[Schedule::Manager] Add: #{params}"
    end

    def event_by_type(type)
      @events.find do |event|
        event["expire_at"] > Time.now.to_i && event["type"] == type
      end
    end

    def expire
      @events.reject! do |event|
        Time.now.to_i >= event["expire_at"]
      end
    end

  end
end
