# Initial client configuration for a newly connected client
class ClientConfigurationMessage < BaseMessage
  data_fields :entity_id, :player_configuration, :client_configuration, :zone_configuration
  configure compression: true, json: true

  def data_log
    if Deepworld::Env.development?
      "Entity ID: #{data[0]}"
    else
      nil
    end
  end
end