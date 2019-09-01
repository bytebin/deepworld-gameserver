class DialogCommand < BaseCommand
  data_fields :dialog_id, :values

  def execute
    case @dialog_id
    when Fixnum
      player.respond_to_dialog @dialog_id, @values

    when 'skill_upgrade'
      Players::SkillUpgrade.new(player)

    when 'player'
      Players::Menu.new(player, @values)

    end
  end

end