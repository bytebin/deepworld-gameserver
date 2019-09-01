module Behavior
  class FlyToward < Fly

    def target_point
      get_target_point
    end

    def backing_off?
      return false if @options['melee'] == true

      tpt = target_point
      return false unless tpt && tpt.x && tpt.y

      (entity.position - tpt).magnitude < 2 && behaved_within?(3)
    end

    def speed_multiplier
      1.25
    end

    def can_behave?
      has?(:target) && !backing_off?
    end

  end
end
