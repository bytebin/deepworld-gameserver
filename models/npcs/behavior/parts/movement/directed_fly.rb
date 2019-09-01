module Behavior
  class DirectedFly < Rubyhave::Behavior
    include TargetHelpers

    def behave(params = {})
      complete_block! get(:target)
      Rubyhave::SUCCESS
    end

    def can_behave?(params = {})
      can_reach_directed_target?
    end

  end
end