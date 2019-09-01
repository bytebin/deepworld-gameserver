class WaypointMessage < BaseMessage
  data_fields :x, :y, :entity_id, :details

  def data_log
    nil
  end
end