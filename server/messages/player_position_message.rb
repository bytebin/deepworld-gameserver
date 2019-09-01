# Player position correction sent when the server disagrees with a player's
# reported location
class PlayerPositionMessage < BaseMessage
  data_fields :x, :y, :velocity_x, :velocity_y

  def data_log
    nil
  end
end