module Behavior
  class ServantDump < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @action_interval = 1
      @last_action_at = Time.now
    end

    def behave(params = {})
      if Ecosystem.time > @last_action_at + adjusted_action_interval
        block = get(:target)
        dump! block
      end

      Rubyhave::SUCCESS
    end

    def dump!(block)
      if has_liquid?
        unless protected?(block)
          if can_dump_on?(block)
            # Pick a random liquid
            liquid = get(:liquid)
            type = liquid.keys.random

            # Determine how much to dump and remove it from store
            amt = [LIQUID_LEVELS, liquid[type]].min
            liquid[type] -= amt
            liquid.delete type if liquid[type] <= 0

            # Remove liquid from world
            zone.update_block nil, block.x, block.y, LIQUID, type, amt

            @last_action_at = Ecosystem.time

            # Emotes
            if rand < 0.02
              entity.emote Game.fake('butler-dump')
            end
          end
        end

        # Complete so we go to next block
        complete_block! block
      end
    end

    def has_liquid?
      if (get(:liquid).values.sum || 0) > 0
        true
      else
        entity.emote Game.fake('butler-dump-empty')
        get(:directed_blocks).clear
        false
      end
    end

    def can_dump_on?(block)
      front = Game.item(zone.peek(block.x, block.y, FRONT)[0])
      return false if front.whole

      liquid = zone.peek(block.x, block.y, LIQUID)
      return false if liquid[0] > 0 && liquid[1] > 0

      true
    end

    def can_behave?(params = {})
      can_reach_directed_target?
    end

  end
end