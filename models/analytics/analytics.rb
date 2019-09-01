require 'digest'

class Analytics

  def self.track(player, category, data)
    if player && player.current_session
      post category, {
        user_id: player.signup_ip || player.id.to_s,
        session_id: player.current_session.id.to_s,
        build: player.platform || 'Unknown',
        platform: player.platform_group
      }.merge(data)
    end
  end

  def self.track_event(player, category, event, data = nil)
    data ||= {}
    data.merge! event_id: "#{event}", area: player.zone_id.to_s
    data.merge! x: player.position.x.to_i, y: player.position.y.to_i if player.position
    track player, category, data
  end

  def self.post(category, data)
    return unless Deepworld::Env.production?

    game_key = Deepworld::Settings.game_analytics.game_key || 'game'
    secret_key = Deepworld::Settings.game_analytics.secret_key || 'secret'

    json = data.to_json
    md5 = Digest::MD5.new
    md5.update json
    md5.update secret_key

    request = {
      head: {
        'Authorization' => md5.hexdigest,
        'Content-Type' => 'application/json'
      },
      body: json
    }

    endpoint_url = "http://api.gameanalytics.com/1"
    url = "#{endpoint_url}/#{game_key}/#{category}"

    p "Analytics: #{url} -- #{data}" if Deepworld::Env.development?
    http = EventMachine::HttpRequest.new(url, request).post(request)
    http.errback { |h| p "Err: #{h.response}" if Deepworld::Env.development? }
    http.callback { |h| p "Callback: #{h.response}" if Deepworld::Env.development? }
  end

end