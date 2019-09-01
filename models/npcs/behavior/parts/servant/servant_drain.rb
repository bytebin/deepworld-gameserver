module Behavior
  class ServantDrain < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @action_interval = 1
      @last_action_at = Time.now
    end

    def after_add
      set(:liquid, {})
    end

    def behave(params = {})
      if Ecosystem.time > @last_action_at + adjusted_action_interval
        block = get(:target)
        drain! block
      end

      Rubyhave::SUCCESS
    end

    def drain!(block)
      unless protected?(block)
        peek = zone.peek(block.x, block.y, LIQUID)
        if peek[0] > 0 && peek[1] > 0
          # Only allow advanced butlers to pick up acid/lava
          liquid_item = Game.item(peek[0])
          if get(:level) >= (liquid_item.drain_level || 1)
            # Remove liquid from world
            zone.update_block nil, block.x, block.y, LIQUID, 0, 0

            # Store internally
            get(:liquid)[peek[0]] ||= 0
            get(:liquid)[peek[0]] += peek[1]

            @last_action_at = Ecosystem.time

            # Emotes
            if rand < 0.02
              entity.emote Game.fake('butler-drain')
            end
          else
            entity.emote Game.fake('butler-low-level')
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