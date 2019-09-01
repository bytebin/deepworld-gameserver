module Entities
  module Effectable

    attr_reader :active_attacks, :active_defenses

    def initialize_effects(config)
      @active_attacks = []
      @active_defenses = []
      @base_defenses = {}

      calculate_base_defenses config if config
    end

    def calculate_base_defenses(config)
      Game.config.damage.each_pair do |type, type_config|
        @base_defenses[type] = 0
        if config.defense
          @base_defenses[type] += (config.defense['all'] || 0) + (config.defense[type] || 0)
        end
        if config.weakness
          @base_defenses[type] -= (config.weakness['all'] || 0) + (config.weakness[type] || 0)
        end
      end
    end



    # ===== Managing effects ===== #

    def add_attack(source, item, options)
      # Reject any existing attacks by source in same slot
      @active_attacks.reject!{ |a| a.source == source && a.slot && a.slot == options[:slot] }

      # Add attack
      attack = Effect::Attack.new(source, self, item, options)

      # If attack is instant (damage duration = -1), apply immediately
      if attack.duration == -1
        attack.process 1.0
      else
        @active_attacks << attack
      end
    end

    def add_defense(source, item, options)
      @active_defenses << Effect::Defense.new(source, self, item, options)
    end

    def cancel_attack(source, slot = nil)
      @active_attacks.reject!{ |a| a.source == source && (slot.nil? || a.slot == slot) }
    end

    def cancel_defense(type = nil)
      @active_defenses.reject!{ |d| type.nil? || d.type == type }
    end




    # ===== Querying ===== #

    def active_attackers
      @active_attacks.map(&:source).uniq
    end

    def active_attack_types
      @active_attacks.map(&:type).uniq
    end

    def base_defense(type)
      @base_defenses[type] || 0
    end

    def defense(type)
      base_defense(type) + @active_defenses.inject(0) do |amt, d|
        amt += d.amount if d.type == type
        amt
      end
    end




    # ===== Processing ===== #

    def process_effects(delta_time = 0)
      clear_inactive_effects
      @active_attacks.each{ |e| e.process delta_time } if delta_time > 0
    end

    def clear_inactive_effects
      @active_attacks.select!{ |e| e.active? }
      @active_defenses.select!{ |e| e.active? }
    end

  end
end