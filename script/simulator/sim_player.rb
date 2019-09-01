require 'zlib'

class SimPlayer < EventMachine::Connection
  WORD_LIST = ["Aardvark", "Abacus", "Abundance", "Ache", "Acupuncture", "Airbrush", "Alien", "Anagram", "Angle", "Amazing", "Ankle", "Alphabet", "Antenna", "Aqua", "Asphalt", "Bacon", "Banana", "Bangles", "Banjo", "Bankrupt", "Bar", "Barracuda", "Basket", "Beluga", "Binder", "Birthday", "Bisect", "Blizzard", "Blunderbuss", "Boa", "Bog", "Bounce", "Broomstick", "Brought", "Bubble", "Budgie", "Bug", "Bug-a-boo", "Bugger", "Buff", "Burst", "Butter", "Buzz", "Cabana", "Cake", "Calculator", "Camera", "Candle", "Carnival", "Carpet", "Casino", "Cashew", "Catfish", "Ceiling", "Celery", "Chalet", "Chalk", "Chart", "Cheddar", "Chesterfield", "Chicken", "Chinchill", "Chit-Chat", "Chocolate", "Chowder", "Coal", "Compass", "Compress", "Computer", "Conduct", "Contents", "Cookie", "Copper", "Corduroy", "Cow", "Cracker", "Crackle", "Croissant", "Cube", "Cupcake", "Curly", "Curtain", "Cushion", "Cuticle", "Daffodil", "Delicious", "Dictionary", "Dimple", "Ding-a-ling", "Disk", "Disco Duck", "Dodo", "Dolphin", "Dong", "Donuts", "Dork", "Dracula", "Duct Tape", "Effigy", "Egad", "Elastic", "Elephant", "Encasement", "Erosion", "Eyelash", "Fabulous", "Fantastic", "Feather", "Felafel", "Fetish", "Financial", "Finger", "Finite", "Fish", "Fizzle", "Fizzy", "Flame", "Flash", "Flavour", "Flick", "Flock", "Flour", "Flower", "Foamy", "Foot", "Fork", "Fritter", "Fudge", "Fungus", "Funny", "Fuse", "Fusion", "Fuzzy", "Garlic", "Gelatin", "Gelato", "Ghetto", "Glebe", "Glitter", "Glossy", "Groceries", "Goulashes", "Guacamole", "Gumdrop", "Haberdashery", "Hamster", "Happy", "Highlight", "Hippopotamus", "Hobbit", "Hold", "Hooligan", "Hydrant", "Icicles", "Idiot", "Implode", "Implosion", "Indeed", "Issue", "Itchy", "Jell-O", "Jewel", "Jump", "Kabob", "Kasai", "Kite", "Kiwi", "Ketchup", "Knob", "Laces", "Lacy", "Laughter", "Laundry", "Leaflet", "Legacy", "Leprechaun", "Lollypop", "Lumberjack", "Macadamia", "Magenta", "Magic", "Magnanimous", "Mango", "Margarine", "Massimo", "Mechanical", "Medicine", "Meh", "Melon", "Meow", "Mesh", "Metric", "Microphone", "Minnow", "Mitten", "Mozzarella", "Muck", "Mumble", "Mushy", "Mustache", "Nanimo", "Noodle", "Nostril", "Nuggets", "Oatmeal", "Oboe", "O'clock", "Octopus", "Odour", "Ointment", "Olive", "Optic", "Overhead", "Ox", "Oxen", "Pajamas", "Pancake", "Pansy", "Paper", "Paprika", "Parmesan", "Pasta", "Pattern", "Pecan", "Peek-a-boo", "Pen", "Pepper", "Pepperoni", "Peppermint", "Perfume", "Periwinkle", "Photograph", "Pie", "Pierce", "Pillow", "Pimple", "Pineapple", "Pistachio", "Plush", "Polish", "Pompom", "Poodle", "Pop", "Popsicle", "Prism", "Prospector", "Prosper", "Pudding", "Puppet", "Puzzle", "Queer", "Query", "Radish", "Rainbow", "Ribbon", "Rotate", "Salami", "Sandwich", "Saturday", "Saturn", "Saxophone", "Scissors", "Scooter", "Scrabbleship", "Scrunchie", "Scuffle", "Shadow", "Sickish", "Silicone", "Slippery", "Smash", "Smooch", "Smut", "Snap", "Snooker", "Socks", "Soya", "Spaghett", "Sparkle", "Spatula", "Spiral", "Splurge", "Spoon", "Sprinkle", "Square", "Squiggle", "Squirrel", "Statistics", "Stuffing", "Sticky", "Sugar", "Sunshine", "Super", "Swirl", "Taffy", "Tangy", "Tape", "Tat", "Teepee", "Telephone", "Television", "Thinkable", "Tip", "Tofu", "Toga", "Trestle", "Tulip", "Turnip", "Turtle", "Tusks", "Ultimate", "Unicycle", "Unique", "Uranus", "Vegetable", "Waddle", "Waffle", "Wallet", "Walnut", "Wagon", "Window", "Whatever", "Whimsical", "Wobbly", "Yellow", "Zap", "Zebra", "Zigzag", "Zip"]
  BLOCK_BUFFER = 50
  MAXIMUM_BLOCK_REQUEST_SIZE = 5

  # Connection states
  INITIALIZED = 0; READY = 1

  def self.connect!(player_data, &block)
    GATEWAY.authenticate(player_data[:name], player_data[:password]) do |auth|
      player_data[:server] = auth['server'].split(":")[0]
      player_data[:port] = auth['server'].split(":")[1]
      player_data[:auth_token] = auth['auth_token']

      yield EM.connect(player_data[:server], player_data[:port], SimPlayer, player_data)
    end
  end

  def initialize(player_data)
    @player = Hashie::Mash.new(player_data)
    @step_mod = 0

    @max_speed = 1

    @message_queue = EM::Queue.new
    @command_queue = EM::Queue.new
  end

  def initialize_session
    @notified = false
    @position_set = false
    @zone_configured = false

    @chunks = {}
    @last_message = nil

    @position = Vector2.new(0, 0)
    @zone_size = Vector2.new(0, 0)
    @chunk_size = Vector2.new(0, 0)
    @velocity = Vector2.new(0, 0)

    # Authenticate
    send_command(:authenticate, ['9.9.9', @player.name, @player.auth_token])
    puts "Authenticating #{@player.name} to #{@player.server}:#{@player.port}"
  end

  def post_init
    load_timer

    initialize_session
  end

  def load_timer
    EventMachine::add_periodic_timer(0.125) { step! }
    EventMachine::add_periodic_timer(rand(2) + 5) { unbind }
  end

  def step!
    return unless connection_state == READY

    @step_mod += 1
    @step_mod = 0 if @step_mod % 480 == 0 # 480 = 60 seconds

    behave

    # Half second
    if @step_mod % 4 == 0
      update_chunks
    end

    # Second
    if @step_mod % 8 == 0
      update_chunks
    end

    # 30 seconds
    if @step_mod % 240 == 0
      #teleport! if rand(3) == 2
    end
  end

  def behave
    @position.x = @position.x + rand((@max_speed * 2) + 1) - @max_speed
    @position.y = @position.y + rand((@max_speed * 2) + 1) - @max_speed

    send_command(:move, [@position.x * 100, @position.y * 100, 100, 100, 0, 0, 0, 0]) unless (ENV['MOVE'] && !ENV['MOVE'].to_bool) || (ENV['MOVE_ONCE'] && @moved)

    send_command(:chat, [nil, chat_message]) if rand < 0.001

    @moved = true
  end

  def teleport!
    search = (['Random'] * 5 + ['Popular']).sample

    send_command(:respawn, [])
    send_command(:zone_search, [search])
    # When search command comes in, the sim will randomly chose one
  end

  def heartbeat
    send_command(:heartbeat, [0, 0])
  end

  def update_chunks
    required = required_chunks

    # Ignore and discard unneeded chunks
    ignore = @chunks.keys - required

    if ignore.count > 0
      send_command(:blocks_ignore, [ignore])
      ignore.each { |c| @chunks.delete(c) }
      #puts "#{player.name} ignored chunks #{ignore}"
    end

    # Request new chunks
    needed = required - @chunks.keys
    if needed.count > 0
      send_command(:blocks_request, [needed.first(MAXIMUM_BLOCK_REQUEST_SIZE)])
      #puts "#{player.name} requested chunks #{needed.first(MAXIMUM_BLOCK_REQUEST_SIZE)}"
    end
  end

  def send_command(ident, data)
    #puts "Sending command #{ident}"
    @command_queue.push([ident, data])

    @command_queue.pop do |m|
      ident, data = m
      ident = ident.is_a?(Symbol) ? CommandDirectory.ident_for(ident) : ident
      data = MessagePack.pack(data)

      send_data [ident, data.bytesize].pack('CL')
      send_data data
    end
  end

  def queue_message(message)
    @message_queue.push(message)

    @message_queue.pop do |m|
      case m.ident

      when BaseMessage::MESSAGES['KickMessage']
        puts "#{@player.name} kicked: #{message[:reason]}"

      when BaseMessage::MESSAGES['NotificationMessage']
        @notified = true if message[:status] == 333

      when BaseMessage::MESSAGES['ClientConfigurationMessage']
        @zone_size.x, @zone_size.y = message[:zone_configuration]['size']
        @chunk_size.x, @chunk_size.y = message[:zone_configuration]['chunk_size']
        @zone_configured = true

      when BaseMessage::MESSAGES['PlayerPositionMessage']
        @position.x, @position.y, @velocity.x, @velocity.y = message.data
        @position_set = true

      when BaseMessage::MESSAGES['ZoneSearchMessage']
        zone_id = message.data[3].map{|z| z[0]}.sample

        send_command(:zone_change, [zone_id])
      else
        # Other shit
      end
    end
  end

  def connection_state
    (@notified and @position_set and @zone_configured) ? READY : INITIALIZED
  end

  def required_chunks
    rect = Rect.new(@position.x - BLOCK_BUFFER, @position.y - BLOCK_BUFFER, BLOCK_BUFFER, BLOCK_BUFFER)
    rect = rect.clamp(Rect.new(0, 0, @zone_size.x, @zone_size.y))

    required = []

    ((rect.left)..(rect.right)).step(@chunk_size.x) do |x|
      ((rect.top)..(rect.bottom)).step(@chunk_size.y) do |y|
        required << chunk_index(x, y)
      end
    end

    required
  end

  def chunk_index(x, y)
    (y / @chunk_size.y).floor * (@zone_size.x / @chunk_size.x) + (x / @chunk_size.x).floor
  end

  def receive_data(data)
    begin
      @data_buffer  ||= ''
      @msg_buffer   ||= []
      @bytesize     ||= 0

      @data_buffer  << data
      @bytesize     += data.size

      # Get the message identifier
      if @msg_buffer.length == 0
        if @bytesize >= 1
          @msg_buffer << @data_buffer.slice!(0).unpack('C')[0]
          @bytesize -= 1
        end
      end

      # Get the data length
      if @msg_buffer.length == 1
        if @bytesize >= 4
          @msg_buffer << @data_buffer.slice!(0..3).unpack('L')[0]
          @bytesize -= 4
        end
      end

      # Get the data
      if @msg_buffer.length == 2
        if @bytesize >= @msg_buffer[1]
          packed = @data_buffer.slice!(0..(@msg_buffer[1]-1))
          @bytesize -= @msg_buffer[1]

          message_class = BaseMessage[@msg_buffer[0]]

          packed = Zlib::Inflate.inflate(packed) if message_class.compress?
          unpacked = MessagePack.unpack(packed)
          @msg_buffer << unpacked

          # Prepacked messages can't be directly instantiated with unpacked data
          if message_class.prepacked?
            handle_prepacked_message(message_class, unpacked)

          # Normal messages
          else
            if message_class.collection_message?
              message = message_class.new(@msg_buffer[2])
            else
              message = message_class.new(*@msg_buffer[2])
            end

            @last_message = message

            queue_message(message)
          end

          @msg_buffer.clear
        end
      end
    rescue
      puts "[Error] Data receipt error. Reconnecting. (#{$!}, #{$!.backtrace.first(2)})"
      close_connection_after_writing
    end
  end

  def unbind
    #puts "Last message: \n#{@last_message.data}" if @last_message
    puts "#{@player.name} disconnected. Reconnecting..."

    reup
  end

  def reup
    GATEWAY.authenticate(@player.name, @player.password) do |auth|
      @player.auth_token = auth['auth_token']

      host, port = auth['server'].split(":")

      reconnect host, port.to_i
      initialize_session
    end
  end

  def handle_prepacked_message(clazz, data)
    if clazz == BlocksMessage
      blocks_message data
    end
  end

  def blocks_message(chunks)
    if connection_state == READY
      indexes = []
      chunks.each do |chunk|
        index = chunk_index(chunk[0], chunk[1])
        @chunks[index] = nil

        indexes << index
      end
    end
  end

  def chat_message
    sentence = [WORD_LIST.random(rand(8) + 1)].flatten.join(' ').downcase
    sentence[0] = sentence[0].upcase
    sentence
  end
end
