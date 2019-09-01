module Behavior
  class Follow < Rubyhave::Behavior
    def behave(params = {})
      if target = get(:target)
        entity.direction = target.position.x - entity.position.x > 0 ? 1 : -1
      end
    end

    def can_behave?(params = {})
      true
    end
  end
end
