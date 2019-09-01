module Behavior
  class RetaliatoryTarget < Rubyhave::Behavior
    include TargetHelpers

    def on_initialize
      @range = @options['range'] || 10
      @attacking = nil
    end

    def behave(params = {})
      if @attacking
        @attacking = nil unless target_alive?(@attacking)
      end

      @attacking = latest_attacker || @attacking

      set(:target, @attacking) if @attacking && target_in_range?(@attacking, @range) && target_visible?(@attacking)
    end

    def latest_attacker
      entity.active_attackers.keys.last if entity.active_attackers.length > 0
    end

    def can_behave?(params = {})
      !behaved_within?(0.25)
    end

  end
end