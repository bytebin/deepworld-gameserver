module Behavior
  class ServantPlace < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @action_interval = 0.5
      @last_action_at = Time.now
    end

    def behave(params = {})
      place_after_interval!
      Rubyhave::SUCCESS
    end

    def place_after_interval!
      if Ecosystem.time > @last_action_at + adjusted_action_interval
        block = get(:target)
        place! block
      end
    end

    def place!(block)
      if has_inventory? and can_place_inventory?
        unless protected?(block)
          item = get(:item)

          layer = nil
          if item.layer == 'front'
            layer = FRONT
          elsif item.layer == 'back'
            layer = BACK
          end

          if layer
            get(:owner).surrogate_place! [block.x, block.y, layer, item.code, 0]
            @last_action_at = Ecosystem.time

            # Emotes
            if rand < 0.02
              entity.emote Game.fake('butler-place')
            end
          end
        end

        # # Complete so we go to next block
        complete_block! block
      end
    end

    def item
      get(:item)
    end

    def has_inventory?
      if item
        if get(:owner).inv.contains?(item.code)
          return true
        else
          entity.emote Game.fake('butler-empty').sub(/\$\$/, item.title.downcase)
        end
      else
        entity.emote Game.fake('butler-no-item')
      end

      get(:directed_blocks).clear
      false
    end

    def can_place_inventory?
      if %w{tools consumables accessories}.include?(item.category) || item.place_entity || !item.block_size
        entity.emote "I can't place this #{item.title.downcase}."
      elsif !item.tileable && (item.block_size[0] > 1 || item.block_size[1] > 1)
        entity.emote "This #{item.title.downcase} is to big for me to place."
      else
        return true
      end

      get(:directed_blocks).clear
      false
    end

    def can_behave?(params = {})
      can_reach_directed_target?
    end

  end
end