module Behavior
  class ServantBlast < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @action_interval = 1.7
      @blast_power = 3
      @blast_cost = 2
      @fuel_item = Game.item('ammo/gunpowder')
      @last_blast_at = Time.now
    end

    def behave(params = {})
      if Ecosystem.time > @last_blast_at + adjusted_action_interval
        block = get(:target)
        blast! block
      end

      Rubyhave::SUCCESS
    end

    def blast!(block)
      if has_fuel?
        # Remove fuel
        get(:owner).inv.remove @fuel_item.code, @blast_cost, true
        get(:owner).emote "-#{@blast_cost} #{@fuel_item.title}"

        # Blow stuff up
        zone.explode block, @blast_power, get(:owner) || entity, true, 4, ['crushing', 'fire'], 'bomb'
        complete_block! block
        @last_blast_at = Ecosystem.time

        # Emotes
        if rand < 0.1
          entity.emote Game.fake('butler-blast')
        end
      end
    end

    def has_fuel?
      if get(:owner).inv.contains?(@fuel_item.code, @blast_cost)
        true
      else
        entity.emote Game.fake('butler-empty').sub(/\$\$/, @fuel_item.title.downcase)
        get(:directed_blocks).clear
        false
      end
    end

    def can_behave?(params = {})
      can_reach_directed_target?
    end

  end
end