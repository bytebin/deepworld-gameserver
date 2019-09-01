module Connection
  attr_accessor :player, :message_queue
  attr_reader :disconnected, :ip_address

  # Client connect
  def post_init
    if ['development', 'test'].include?(Deepworld::Env.environment)
      LOADER.reload!
      Game.latest_connection = self
    end

    @command_queue = EM::Queue.new
    @message_queue = EM::Queue.new

    @disconnected = false
    @data_buffer = []
    @data_buffer_size = 0

    @recent_commands = {}
    @last_throttle_alert_at = Time.now - 1.day
    @throttlings = 0

    @debug_commands = []
  end

  def receive_data(data)
    return if @disconnected

    unless @ip_address
      port, @ip_address = Socket.unpack_sockaddr_in(get_peername)
    end

    idx = 0

    unless @command_ident
      @command_ident = data.slice(0).unpack('C')[0]
      return if (idx += 1) >= data.length
    end

    unless @command_length
      if @command_length_buffer.nil? && data.length >= 4
        @command_length = data.slice(idx, 4).unpack('L')[0]
        idx += 4
      else
        @command_length_buffer ||= ''
        bytes_left = [4 - @command_length_buffer.length, data.length - idx].min
        @command_length_buffer << data.slice(idx, bytes_left)

        if @command_length_buffer.length == 4
          @command_length = @command_length_buffer.unpack('L')[0]
        end

        idx += bytes_left
      end
    end

    return if idx >= data.length

    max_len = @command_ident == 54 ? 4096 : 1024
    if !(0..max_len).include?(@command_length) && !player.try(:admin)
      kick "Invalid message length"
      return
    end

    bytes_left = [@command_length - @data_buffer_size, data.length - idx].min

    data_slice = idx == 0 && bytes_left == data.size ? data : data.slice(idx, bytes_left)
    @data_buffer << data_slice
    @data_buffer_size += data_slice.size
    idx += bytes_left

    if @data_buffer_size == @command_length
      if command_class = CommandDirectory[@command_ident]
        command_data = nil
        if @data_buffer_size > 0
          begin
            if Deepworld::Env.development?
              @debug_commands << "#{command_class}: #{@command_length} bytes - #{@data_buffer.join}"
              @debug_commands.shift if @debug_commands.size > 5
            end
            command_data = MessagePack.unpack(@data_buffer.join)
          rescue
            p "Network mixup: #{command_class} with #{@data_buffer_size} bytes."
            @debug_commands.each{ |c| p c } if Deepworld::Env.development?
            kick 'Oops, the network got mixed up!'
          end
        end
        command = command_class.new(command_data, self)
        queue_command(command)
      end

      # Clear out command
      @command_ident = @command_length = @command_length_buffer = nil
      @data_buffer.clear
      @data_buffer_size = 0

      # If bytes remain, run through again
      if idx < data.length
        receive_data data[idx..-1]
      end
    end
  end

  def outbound_size
    get_outbound_data_size
  end

  # Client disconnect
  def unbind
    self.close unless @disconnected
  end

  def kick(message, should_reconnect = false)
    @disconnected = true
    send_message KickMessage.new(message, should_reconnect)
    p "[Connection] Kicked #{@player.try(:name)} (#{message}, #{should_reconnect})" if Deepworld::Env.development?

    self.close
  end

  def close(swapping = false)
    @disconnected = true
    close_connection_after_writing

    if !swapping
      if @player && @player.played
        # Persist the player's info
        @player.before_quit
        @player.inv.save!
        @player.save!
        @player.record_session
      end

      if self.zone
        # Remove the player from the zone and game
        zone.remove_player(@player) if self.zone
        Game.remove_connection(self, self.zone.id)
      end
    end
  end

  def peers
    zone.players.reject { |p| p == @player }
  end

  def throttle_command?(command)
    if throttle = command.class.throttle_level
      cmds = @recent_commands[command.class] ||= []

      # Kill old commands
      threshold = Time.now - throttle[1]
      cmds.reject!{ |c| c < threshold }

      # Record this command
      cmds << Time.now

      if cmds.size > throttle.first

        # Send alert if configured and it's been long enough since last one
        if throttle[2] && Time.now > @last_throttle_alert_at + 1.second
          player.alert throttle[2].is_a?(String) ? throttle[2] : 'Please slow down your requests.'
          @last_throttle_alert_at = Time.now
        end

        # Kick if throttlings exceeds threshold
        @throttlings += 1
        if @throttlings > 20
          kick "Your app is behaving erratically. Please restart."
        end

        return true
      end
    end

    false
  end

  def queue_command(command, zone_id = nil)
    @command_queue.push(command)

    EM.next_tick do
      @command_queue.pop do |c|
        if @player.nil? && c.class.name != 'AuthenticateCommand'
          kick('Not logged in yet.', false)
        else
          c.execute!
        end
      end
    end
  end

  def queue_message(message)
    [*message].each do |message|
      #p "queue msg #{message}" if Deepworld::Env.development?
      message.filter(@player)
      message.validate

      if message.errors.present?
        Game.info({ message: "Message #{message.class.name} failed validation: #{message.errors}", backtrace: Kernel.caller[3..-1] }, true)
      elsif message.data.present?
        @message_queue.push(message)

        EM.next_tick do
          @message_queue.pop do |m|
            send_message(m)
            m.log!(@player, self.zone) if Deepworld::Env.development?
          end
        end
      end
    end
  end

  def queue_peer_messages(message)
    peers.each do |peer|
      peer.connection.queue_message message unless zone.tutorial? && !peer.admin?
    end
  end

  def queue_tracked_peer_messages(message)
    peers.each do |peer|
      if peer.tracking_entity?(@player.entity_id)
        peer.connection.queue_message message unless zone.tutorial? && !peer.admin?
      end
    end
  end

  def notify(message, status = 0)
    queue_message NotificationMessage.new(message, status)
  end

  def notify_peers(message, status = 0)
    peers.each { |peer| peer.connection.notify(message, status) } unless zone.tutorial?
  end

  def zone
    @player.zone if @player
  end

  private

  def send_message(message)
    data = nil

    if message.class.prepacked?
      data = message.data.first
    elsif message.class.json? && @player.v3?
      data = JSON.generate(message.data)
      File.open('tmp/server_config.json', 'w'){ |f| f.write data } if Deepworld::Env.development?
    else
      Game.add_benchmark :message_pack do
        data = MessagePack.pack(message.data)
      end
    end

    if message.class.compress?
      Game.add_benchmark :message_pack_compress do
        data = Zlib::Deflate.deflate(data, Zlib::BEST_SPEED)
      end
    end

    send_data [message.ident, data.bytesize].pack('CL')

    send_data data
  end
end