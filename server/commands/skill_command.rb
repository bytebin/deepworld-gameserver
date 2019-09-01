class SkillCommand < BaseCommand
  data_fields :skill, :level

  def execute
    player.upgrade_skill skill, level
    player.alert "Your #{skill} skill is now level #{player.skill(skill)}!"

    # Send upgrade hint if free player is maxing out
    if !player.premium && player.skills[skill] >= 3
      player.send_hint "buy-premium-skill-#{skill}"
    end

    player.queue_message EventMessage.new('uiHints', [])
  end

  def validate
    run_if_valid { @errors << "#{skill} is not a valid skill" unless Player::SKILLS.include? skill }
    run_if_valid { @errors << "Not enough points" unless player.points > 0 || @level }

    unless player.admin?
      run_if_valid { @errors << "Can't override skill" if @level }
      run_if_valid { @errors << "This skill has been maxed out" if player.skills[skill] >= player.max_skill_level }
    end
  end
end
