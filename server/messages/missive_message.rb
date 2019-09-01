# Missive feed
class MissiveMessage < BaseMessage
  configure collection: true

  data_fields :id, :type, :date, :sender, :message, :read

  def data_log
    nil
  end
end