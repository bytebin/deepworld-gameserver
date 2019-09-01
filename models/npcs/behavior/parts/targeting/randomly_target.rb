module Behavior
  class RandomlyTarget < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @range                = @options['range'] || 20
      @friendly_fire        = @options['friendly_fire'] != false
      @owner                = entity.meta_block.try(:player_id)
      @target_locked_at     = 0
      @target_lock_period   = 5
      @blockable = @options['blockable'].nil? ? true : @options['blockable']
    end

    def behave(params = {})
      # Forget the target when surpassing the lock period
      if has? :target
        clear(:target) if (Ecosystem.time - @target_locked_at) > @target_lock_period
      end

      # Forget the target if they've become friends
      if !@friendly_fire && target = get(:target)
        clear(:target) if is_followee(target)
      end

      # Forget the target if they're gone, or not visible
      if target = get(:target)
        clear(:target) unless target_acquirable?(target, @range, @blockable)
      end

      acquire_target unless has?(:target)

      if @options['animation'] && has?(:target)
        entity.animate @options['animation']
      end
    end

    def acquire_target
      if target = @friendly_fire ? random_player(@range) : enemy_target(@range, @owner)
        set(:target, target)
        @target_locked_at = Ecosystem.time
      end

      target
    end

    def can_behave?(params = {})
      return false if @owner && entity.zone.suppress_turrets

      !behaved_within?(0.5)
    end

    def is_followee(player)
      if @owner
        player.id != BSON::ObjectId(@owner) && !player.followers.include?(BSON::ObjectId(@owner))
      else
        false
      end
    end
  end
end
