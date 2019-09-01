module Behavior
  class Reporter < Rubyhave::Behavior

    def behave
      entity.report_health
      return Rubyhave::SUCCESS
    end

  end
end
