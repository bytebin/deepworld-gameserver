module Players
  module Skills
    SKILLS = %w{agility automata building combat engineering horticulture luck mining perception science stamina survival}
    ADVANCED_SKILLS = %w{automata science horticulture luck}
    DELETE_SKILLS = %w{agil auto buil clim engi meta mini perc stam surv}

    def set_default_skills!
      DELETE_SKILLS.each { |sk| @skills.delete sk }
      SKILLS.each do |skill|
        @skills[skill] ||= 1
      end
    end

    def upgrade_skill(skill, level = nil)
      if skill
        skill = skill.downcase

        if @skills[skill]
          # Admin direct setting of skill level
          if level
            @skills[skill] = level.clamp(1, max_skill_level)

          elsif @points == 0
            return Game.config.dialogs.skill_upgrade_no_points

          elsif @skills[skill] >= max_skill_level
            return Game.config.dialogs.skill_upgrade_maxed

          else
            @skills[skill] += 1
            @points -= 1
          end

          queue_message EventMessage.new('uiHints', [])
          queue_message SkillMessage.new([[skill, @skills[skill]]])
          return Game.config.dialogs.skill_upgrade_success.sub('$1', skill.capitalize).sub('$2', @skills[skill].to_s)
        end
      end
    end

    def upgradeable_skills
      sk = SKILLS.select{ |sk| skill(sk) < max_skill_level }
      sk -= ADVANCED_SKILLS if @level < 10
      sk
    end

    def skill(name)
      @skills[name] || 1
    end

    def max_skill_level
      10
    end

    def adjusted_max_skill_level
      15
    end

    def adjusted_skill(name)
      skill_accessories = self.inv.bonus.select{|a| a.bonus[name]}
      max_accessory_bonus = skill_accessories.map{ |a| a.bonus[name] }.max || 0

      skill_hiddens = self.inv.hidden.select{ |h| h.bonus[name] }
      max_hidden_bonus = skill_hiddens.map{ |h| h.bonus[name] }.max || 0

      skill(name) + max_accessory_bonus + max_hidden_bonus
    end

    def adjusted_skill_normalized(name)
      adjusted_skill(name) / adjusted_max_skill_level.to_f
    end

    def skill_level
      @skills.values.sum - SKILLS.size + 1  # When all skills are at 1, skill level should be 1
    end

    def max_servants
      adjusted_skill('automata') / 3
    end

    def max_transmit_distance
      adjusted_skill('engineering') * 10
    end

    def max_targetable_entities
      1 + (adjusted_skill('agility') / 2)
    end

    def can_double_dig?
      self.inv.bonus.any?{ |a| a.bonus.dig }
    end

    def critical_hit_rate
      1.0.lerp(3.0, adjusted_skill('combat') / adjusted_max_skill_level.to_f)
    end

    def send_skills_message
      queue_message SkillMessage.new(@skills.map{ |name, level| [name, level] }.sort_by{ |sk| sk[0] })
    end

    def send_points_message
      queue_message StatMessage.new('points', points)
    end

  end
end
