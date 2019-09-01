require 'json'

class Gateway
  ENVIRONMENTS = {
    staging: {gateway: 'gateway-staging.deepworldgame.com', gateway_port: 80},
    development: {gateway: '127.0.0.1', gateway_port: 5001}
  }

  HEADERS = {'User-Agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.83 Safari/535.11"}

  attr_reader :auth_url

  def initialize(environment)
    env = ENVIRONMENTS[environment.to_sym]
    @auth_url = "http://#{env[:gateway]}:#{env[:gateway_port]}/sessions"
  end

  def authenticate(player_name, password, &block)
    http = EventMachine::HttpRequest.new(@auth_url).post body: {name: player_name, password: password}

    http.errback do
      puts "[Error] Gateway authentication failed for #{player_name}"
    end

    http.callback do
      if http.response_header.status.to_s == "200"
        response = JSON.parse(http.response)
        yield response
      else
        puts "[Error] Gateway response of #{http.response_header.status} for #{player_name}"
      end
    end
  end
end