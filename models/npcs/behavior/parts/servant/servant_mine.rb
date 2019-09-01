module Behavior
  class ServantMine < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @action_interval = 1
      @last_action_at = Time.now
    end

    def behave(params = {})
      if Ecosystem.time > @last_action_at + adjusted_action_interval
        block = get(:target)
        mine! block
      end

      Rubyhave::SUCCESS
    end

    def mine!(block)
      unless protected?(block)
        layer = nil

        peek = zone.peek(block.x, block.y, FRONT)
        if peek[0] > 0
          layer = FRONT
        else
          peek = zone.peek(block.x, block.y, BACK)
          if peek[0] > 0
            layer = BACK
          end
        end

        # Only mine (and set delay until next mining) if there's something there
        if layer
          get(:owner).surrogate_mine! [block.x, block.y, layer, peek[0], 0]
          @last_action_at = Ecosystem.time

          # Emotes
          if rand < 0.02
            entity.emote Game.fake('butler-mine')
          end
        end
      end

      # Complete so we go to next block
      complete_block! block
    end

    def can_behave?(params = {})
      can_reach_directed_target?
    end

  end
end