require 'timeout'

TIMEOUT = 0.33
MAX = 100

class Message
  attr_accessor :ident, :data

  def initialize(ident, data = nil)
    @ident = ident.is_a?(Symbol) ? CommandDirectory.ident_for(ident) : ident
    @data = data
  end

  def self.receive_one(socket, args={})
    socket = socket.socket if socket.is_a?(Player)
    raise "Socket passed to receive_one is nil" unless socket

    timeout = args[:timeout] || TIMEOUT
    ignore = [args[:ignore]].flatten.compact
    only = [args[:only]].flatten.compact

    @ignore = ignore.collect{|i| i.is_a?(Symbol) ? BaseMessage.ident_for(i) : i}.flatten
    @only = only.collect{|i| i.is_a?(Symbol) ? BaseMessage.ident_for(i) : i}.flatten

    msg = nil

    begin
      ident = nil; data = nil

      while msg.nil? do
        Timeout::timeout(timeout) {
          while !ident || !interested?(ident) do
            ident = nil; len = nil; data = nil;
            return nil unless ident = socket.recv(1).unpack('C')[0]
            len = socket.recv(4).unpack('L')[0]
            data = socket.read(len)
          end
        }

        if interested?(ident)
          msg_class = const_get(BaseMessage::DIRECTORY[ident])
          begin
            data = Zlib::Inflate.inflate(data) if msg_class.compress?
            data = MessagePack.unpack(data)

            if msg_class.prepacked?
              msg = data
            elsif msg_class.collection_message?
              msg = msg_class.new(data)
            else
              msg = msg_class.new(*data)
            end
          rescue
            raise "Unpack error for #{msg_class}: #{$!.message}"
          end
        end
      end
    rescue Timeout::Error
      # Don't do shit
    end

    msg
  end

  def self.receive_many(socket, args={})
    raise "Socket passed to receive_one is nil" unless socket

    max = args[:max] || 100
    messages = []
    msg_count = 0

    while msg_count < max and msg = receive_one(socket, args) do
      if !msg.nil?
        messages << msg
        msg_count += 1
      end
    end

    messages
  end

  def send(socket, packet_size = nil)
    sleep(0.0001)
    packed_data = MessagePack.pack(self.data)

    data = ''
    data << [ident, packed_data.bytesize].pack('CL')
    data << packed_data

    if packet_size
      (data.length / packet_size.to_f).ceil.times.each do |i|
        socket.print data.slice(i * packet_size, [packet_size, data.length - (i * packet_size)].min)
      end
    else
      socket.print(data)
    end
  end

  private

  def self.interested?(ident)
    (@only.empty? || @only.include?(ident)) && !@ignore.include?(ident)
  end
end
