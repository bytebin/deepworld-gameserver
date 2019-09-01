module Behavior
  class DirectedTarget < Rubyhave::Behavior
    include TargetHelpers

    def behave(params = {})
      acquire_target
      has?(:target) ? Rubyhave::SUCCESS : Rubyhave::FAILURE
    end

    def acquire_target
      set :target, get(:directed_blocks).first
    end

  end
end