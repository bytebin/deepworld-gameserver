class EventMachine::Mongo::Connection
  def responses
    instance_variable_get('@em_connection').instance_variable_get('@responses')
  end
end