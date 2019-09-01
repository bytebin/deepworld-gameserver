# Missive info (unread count, etc.)
class MissiveInfoMessage < BaseMessage
  data_fields :type, :data

  def data_log
    nil
  end
end