# Direction 0 means player is following, 1 means other play is following

class FollowMessage < BaseMessage
  configure collection: true

  data_fields :other_player_name, :other_play_id, :direction, :is_following

  def data_log
    nil
  end
end