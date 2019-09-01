module Behavior
  class Fall < Rubyhave::Behavior

    def behave
      entity.speed += 0.5 if entity.speed < 6.0

      entity.move.y = 1
      entity.animate @options['animation'] || 'idle'

      return Rubyhave::SUCCESS
    end

    def can_behave?
      !entity.grounded?
    end

  end
end
