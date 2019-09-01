module Behavior
  class Turn < Rubyhave::Behavior
    def behave
      entity.direction *= -1
      return Rubyhave::SUCCESS
    end


    def can_behave?
      entity.blocked?(entity.direction, 0)
    end
  end
end
