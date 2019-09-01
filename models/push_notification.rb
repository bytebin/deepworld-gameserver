class PushNotification
  MAX_LENGTH = 200

  def self.create(player, message)
    return false if Deepworld::Env.staging?
    return false if player.settings && player.settings['pushMessaging'] == 1

    message

    player_conditions = Deepworld::Env.production? ? { 'playerId' => player.id.to_s } : { 'playerName' => player.name.downcase }
    req = {
      head: {
        'X-Parse-Application-Id' => Deepworld::Settings.parse.app_id,
        'X-Parse-REST-API-Key' => Deepworld::Settings.parse.api_key,
        'Content-Type' => 'application/json'
      },
      body: {
        'where' => player_conditions,
        'data' => { 'alert' => prepare_message(message) }
      }.to_json
    }

    post req

    true
  end

  def self.prepare_message(msg)
    sanitized = Deepworld::Obscenity.sanitize(msg)
    
    # Clip the length and ellipsize
    if sanitized.length > MAX_LENGTH
      sanitized = sanitized[0..(MAX_LENGTH - 4)] + "..."
    end

    sanitized
  end
    
  def self.post(request)
    http = EventMachine::HttpRequest.new('https://api.parse.com/1/push', request).post(request)
    http.errback {}
    http.callback {}
  end

end
