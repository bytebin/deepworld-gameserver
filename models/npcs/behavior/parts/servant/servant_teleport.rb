module Behavior
  class ServantTeleport < Rubyhave::Behavior

    def behave(params = {})
      old_pos = entity.position
      new_pos = get(:owner).position
      entity.position = new_pos
      get(:servant).effect! :teleport

      Rubyhave::SUCCESS
    end

    def can_behave?
      if servant = get(:servant)
        if servant.available_directives.include?('teleport') && get(:level) >= 2 && (!@last_teleported_at || Ecosystem.time > @last_teleported_at + interval)
          if (entity.position - get(:owner).position).magnitude > 20
            @last_teleported_at = Ecosystem.time
            return true
          end
        end
      end

      false
    end

    def interval
      get(:level) >= 3 ? 15.seconds : 30.seconds
    end

  end
end
