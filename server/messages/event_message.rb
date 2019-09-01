class EventMessage < BaseMessage
  data_fields :key, :value

  def data_log
    nil
  end
end