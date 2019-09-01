module Behavior
  class Land < Rubyhave::Behavior
    def on_initialize
      @direction = @options['direction'] == 'top' ? -1 : 1
    end

    def behave
      entity.animation = 1

      return Rubyhave::SUCCESS
    end

    def can_behave?
      entity.blocked?(0, @direction)
    end
  end
end
