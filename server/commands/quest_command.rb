class QuestCommand < BaseCommand
  data_fields :quest_id, :type, :data

  def execute
    case @type
    when 'active'
      player.set_active_quest !!@data ? @quest_id : nil
    end
  end

  def validate
    @errors << 'Invalid quest id' unless quest_id.is_a?(String) && quest_id.size < 100
  end

end