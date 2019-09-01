module Behavior
  class Shielder < Rubyhave::Behavior

    attr_reader :duration, :recharge, :defenses

    def on_initialize
      @duration = @options['duration'] || 5
      @recharge = @options['recharge'] || 5
      @defenses = [*@options['defenses']].compact

      if @defenses.delete('all')
        @defenses += Game.attack_types
      end
      if @defenses.delete('elemental')
        @defenses += [Game.elemental_attack_types.random]
      end

      @duration_left = @duration
      @recharge_left = @recharge
      @current_shield = nil
      @last_set_shield_at = Time.now
    end

    def behave
      active_attack_types = entity.active_attack_types & @defenses
      if active_attack_types.present?
        try_shield active_attack_types, @delta

      # No attacks; deactivate shield if it's been a little bit
      else
        @duration_left = (@duration_left + @delta).clamp(0, @duration)
        set_shield nil if Ecosystem.time > @last_set_shield_at + 2.seconds
      end

      return Rubyhave::SUCCESS
    end

    def try_shield(damage_types, delta = 0)

      # Duration left, so continue to use
      if @duration_left > 0
        @duration_left -= delta

        type = @current_shield && damage_types.include?(@current_shield) ? @current_shield : damage_types.first
        set_shield type

      # Recharging
      else
        set_shield nil

        @recharge_left -= delta
        if @recharge_left < 0
          @recharge_left = @recharge
          @duration_left = @duration
        end
      end
    end

    def set_shield(type = nil)
      if @current_shield != type
        @current_shield = type

        entity.cancel_defense
        if type
          base_defense = entity.base_defense(type)
          entity.add_defense nil, nil, type: type, amount: 1.0 - base_defense
          @last_set_shield_at = Ecosystem.time
        end
        zone.change_entity entity, { 's' => type }
      end
    end

    def react(message, params)
      if message == :damage
        shield_types = [params.first] & @defenses
        try_shield shield_types if shield_types.present?
      end
    end
  end
end
