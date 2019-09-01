# Zone block data containing the contents of the zone
class BlocksMessage < BaseMessage
  configure compression: true, prepacked: true

  data_fields :data

  def data_log
    nil
  end

end