class Server < MongoModel
  fields [:ip_address, :port, :name, :restart, :maintenance, :transition, :kick_players, :happenings]

  # Register server with MCP
  def self.register(ip_address, port, ipv6_address, &block)
    # If this is a 'New' server, default to quarantined (unless in dev)
    details = {
      '$set' => {
        'name' => "#{ip_address}:#{port}",
        'booted_at' => Time.now,
        'reported_at' => Time.now,
        'ip_address' => ip_address,
        'ipv6_address' => ipv6_address,
        'port' => port,
        'restart' => false,
        'active' => true,
        'transition' => false
      },
      '$setOnInsert' => { quarantined: !Deepworld::Env.local? }
    }

    Server.upsert({'ip_address' => ip_address, 'port' => port}, details, false) do
      Server.find_one({'ip_address' => ip_address, 'port' => port}) do |doc|
        yield doc
      end
    end
  end

  def unregister(&block)
    update(active: false) do |doc|
      yield doc
    end
  end
end
