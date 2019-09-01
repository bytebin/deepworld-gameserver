class MongoStatsSink
  COLLECTION = 'machine_stats'
  SERVERS = 'servers'

  def initialize
    @db = connect
  end

  def store(data)
    @db[COLLECTION].insert(data)
    store_server_stats(data)
  end

  private

  def store_server_stats(data)
    ip = data[:ip]
    servers = @db[SERVERS]

    if data[:procs]
      data[:procs].each do |prok|
        servers.update({"ip_address" => ip, "pid" => prok[:pid].to_i}, {"$set" => {"cpu_utilization" => prok[:cpu_util], "memory_usage" => prok[:mem_usage]}})
      end
    end
  end

  def connect
    settings = Deepworld::Settings.mongo
    Deepworld::DB.connect(settings.hosts, settings.database, settings.username, settings.password)
  end
end
