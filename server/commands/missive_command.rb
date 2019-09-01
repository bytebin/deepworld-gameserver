class MissiveCommand < BaseCommand
  data_fields :action, :data
  throttle 2, 1.0

  def execute
    case action
    when 'current'
      Missive.query_for_players player, { '$lt' => Time.now }, -1, 20
    when 'next'
      Missive.query_for_players player, { '$gt' => Time.at(data.to_i) }, 1, 20
    when 'previous'
      Missive.query_for_players player, { '$lt' => Time.at(data.to_i) }, -1, 20, false, true do |missives|
        player.queue_message EventMessage.new('feedDidUpdate', nil)
      end
    when 'read'
      if data.is_a?(Array) && (1..20).include?(data.size) && data.all?{ |d| d.is_a?(String) && d.size == 24 }
        Missive.mark_read player, data
      end
    when 'respond'
      Missive.where(_id: BSON::ObjectId(data), player_id: player.id).first do |missive|
        if missive.type == 'inv'
          Players::Invite.new(player, missive.creator_id).respond!
          missive.update type: 'invr'
        end
      end
    when 'read_all'
      Missive.mark_all_read player
    end
  end

end
