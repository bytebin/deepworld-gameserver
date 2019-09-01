class HeartbeatMessage < BaseMessage
  data_fields :time

  def data_log
    nil
  end
end