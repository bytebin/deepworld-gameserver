# Player chat
class ChatMessage < BaseMessage
  configure collection: true

  data_fields :from_entity_id, :message, :type

  def data_log
    nil
  end
end