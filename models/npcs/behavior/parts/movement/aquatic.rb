module Behavior
  class Aquatic < Rubyhave::Selector

    def on_initialize
      self.add_child behavior(:fall)
      self.add_child behavior(:animate, animation: 'flop')
    end

    def can_behave?(params = {})
      zone.peek(entity.position.x, entity.position.y, LIQUID)[1] <= 2
    end
  end
end
