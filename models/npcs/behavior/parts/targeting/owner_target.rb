module Behavior
  class OwnerTarget < Rubyhave::Behavior
    include TargetHelpers

    def behave(params = {})
      if target = get(:target)
        clear(:target) unless target_acquirable?(target, 50, false)
      end

      acquire_target unless has?(:target)

      has?(:target) ? Rubyhave::SUCCESS : Rubyhave::FAILURE
    end

    def acquire_target
      if entity.owner_id && target = zone.find_player_by_id(entity.owner_id)
        set(:target, target)
      end

      target
    end

  end
end