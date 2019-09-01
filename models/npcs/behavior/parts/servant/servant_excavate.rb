module Behavior
  class ServantExcavate < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @action_interval = 2.5
      @last_action_at = Time.now
    end

    def behave(params = {})
      if Ecosystem.time > @last_action_at + adjusted_action_interval
        block = get(:target)
        excavate! block
      end

      Rubyhave::SUCCESS
    end

    def excavate!(block)
      unless protected?(block)
        is_deep_biome = zone.biome == 'deep'

        if is_deep_biome || (block.y < 200 || block.y > 280)
          if zone.peek(block.x, block.y, FRONT)[0] == 0 && zone.peek(block.x, block.y, BACK)[0] == 0 && Game.item(zone.peek(block.x, block.y, BASE)[0]).excavatable
            zone.update_block nil, block.x, block.y, BASE, is_deep_biome || block.y >= 200 ? 1 : 0

            @last_action_at = Ecosystem.time

            # Emotes
            if rand < 0.02
              entity.emote Game.fake('butler-excavate')
            end
          end
        else
          entity.emote "I cannot excavate near sea level."
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