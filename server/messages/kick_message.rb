# Message send before a client is forcebly disconnected from the server
class KickMessage < BaseMessage
  data_fields :reason, :should_reconnect
end