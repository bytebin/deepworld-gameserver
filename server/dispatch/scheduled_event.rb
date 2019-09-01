module Dispatch
  class ScheduledEvent

    def execute(params)
      Game.schedule.add params
    end

  end
end
