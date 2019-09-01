class ConnectionPool
  POOL_SIZE = 2
  CONNECTION_WAIT = 5

  attr_reader :connections

  def initialize(options = {})
    @host     = options[:host]
    @port     = options[:port]
    @username = options[:username]
    @password = options[:password]
    @database = options[:database]
    @reconnect_in = options[:reconnect_in] || 0.10

    @connections = ThreadSafe::Array.new
    POOL_SIZE.times.map{ add_connection }

    # Top off connection pool every second
    EM.add_periodic_timer(1) { reconnect }
  end

  def connection_count
    @connections.select(&:connected?).length
  end

  def on_connected(&block)
    started_at = Time.now

    if connection_count >= 1
      yield
    elsif started_at - Time.now <= CONNECTION_WAIT
      EM.add_timer(0.1){ self.on_connected { block.call } }
    end
  end

  def db
    if connected = @connections.select(&:connected?)
      connection = connected.min_by{ |c| c.responses.length }
    else
      connection = @connections.sample
    end

    connection.db(@database)
  end

  private

  def add_connection
    connection = EM::Mongo::Connection.new(@host, @port, nil)

    # Authenticate if necessary
    if @username
      req = connection.db(@database).authenticate(@username, @password)

      req.callback do |res|
        if res
          @connections << connection
        else
          raise "Unable to connect to mongodb #{@host}:#{@port}!"
        end
      end

      req.errback do |res|
        raise "Unable to connect to mongodb #{@host}:#{@port} - #{res}"
      end
    else
      @connections << connection
    end
  end

  def reconnect
    replace = []

    @connections.each do |c|
      # Check for disconnected connections
      replace << c unless c.connected?
    end

    # Replace connections if needed
    if replace.count > 0
      Game.info error: "Replacing lost connections: #{replace.count}"
      replace.each { |c| @connections.delete c }
      replace.count.times.each { add_connection }
    end
  end

end