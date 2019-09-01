class BaseMessage
  CONFIGURATION_KEYS = [
    :collection,
    :compression,
    :prepacked,
    :json
  ]

  MESSAGES = {
    'ClientConfigurationMessage'  => 2,
    'BlocksMessage'               => 3,
    'InventoryMessage'            => 4,
    'PlayerPositionMessage'       => 5,
    'EntityPositionMessage'       => 6,
    'EntityStatusMessage'         => 7,
    'EntityChangeMessage'         => 8,
    'BlockChangeMessage'          => 9,
    'EntityItemUseMessage'        => 10,
    'ChatMessage'                 => 13,
    'LightMessage'                => 15,
    'ZoneStatusMessage'           => 17,
    'HealthMessage'               => 18,
    'BlockMetaMessage'            => 20,
    'ZoneSearchMessage'           => 23,
    'FollowMessage'               => 27,
    'AchievementMessage'          => 29,
    'EffectMessage'               => 30,
    'NotificationMessage'         => 33,
    'SkillMessage'                => 35,
    'HintMessage'                 => 36,
    'WardrobeMessage'             => 39,
    'MinigameMessage'             => 40,
    'StatMessage'                 => 44,
    'DialogMessage'               => 45,
    'AchievementProgressMessage'  => 48,
    'TeleportMessage'             => 50,
    'ZoneExploredMessage'         => 53,
    'MissiveMessage'              => 55,
    'MissiveInfoMessage'          => 56,
    'EventMessage'                => 57,
    'UploadMessage'               => 58,
    'XpMessage'                   => 60,
    'LevelMessage'                => 61,
    'QuestMessage'                => 63,
    'WaypointMessage'             => 64,
    'PlayerOnlineMessage'         => 65,
    'HeartbeatMessage'            => 143,
    'KickMessage'                 => 255
  }
  DIRECTORY = MESSAGES.inject({}) { |dir, m| dir[m[1]] = m[0]; dir }

  attr_reader :data, :errors

  class << self
    attr_reader :fields
    attr_reader :configuration
  end

  def initialize(*data)
    @errors = []

    begin
      if self.class.collection_message?
        data = data.flatten(1)
        data = [data] if data == data.flatten(1)
        data.each {|d| self.class.validate_data(d)}
      else
        self.class.validate_data(data)
      end
    rescue
      @errors << $!.to_s
    end

    @data = data || []
  end

  def ident
    MESSAGES[self.class.name] || raise("No id found for message #{self.class.name}")
  end

  def validate
  end

  def filter(player)
    if self.class.collection_message?
      @data = @data.select { |d| should_send?(d, player) }
    else
      @data = [] unless should_send?(@data, player)
    end
  end

  def should_send?(data, player)
    true
  end

  # Get the message based on the id
  def self.[](ident)
    const_get(DIRECTORY[ident]) rescue raise "Missing message '#{ident}'"
  end

  def self.ident_for(*messages)
    [messages].flatten.collect do |m|
      MESSAGES[m.to_s.split('_').collect(&:capitalize).join + 'Message']
    end
  end

  def self.data_fields(*fields)
    @fields ||= []
    @fields = (@fields + fields).uniq
  end

  def self.configure(configuration)
    @configuration ||= {}

    configuration.each do |config|
      CONFIGURATION_KEYS.include?(config[0]) ? @configuration[config[0]] = config[1] : raise("Unknown message configuration #{config[0]}")
    end
  end

  def self.collection_message?
    @configuration && @configuration[:collection]
  end

  def self.compress?
    @configuration && @configuration[:compression]
  end

  def self.prepacked?
    @configuration && @configuration[:prepacked]
  end

  def self.json?
    @configuration && @configuration[:json]
  end

  # Provide access to fields by name
  def [](field_name)
    field_name = field_name.to_sym
    if index = self.class.fields.index(field_name)
      if self.class.collection_message?
        data.each.collect{|d| d[index]}
      else
        data[index]
      end
    else
      throw "No data field named #{field_name}"
    end
  end

  def log!(player, zone)
    # puts "#{player.name.ljust(25)} msg: #{ident}"
    # if ident == 7
    #   info = self.data[0]
    #   puts "entity: #{info[0]} name: #{info[2]} status: #{EntityStatusMessage::STATUS[info[3]]}"
    # end
    return unless log = self.data_log

    data = {}
    data[:message] = "#{self.class.name.sub(/Message$/, 'M')}: #{log}"
    data[:player] = player.name if player
    data[:error] = errors unless errors.blank?
    data[:zone] = zone.id.to_s if zone
    Game.info data
  end

  # Logged version of data
  def data_log
    data.inspect
  end

  private

  def self.validate_data(data)
    if !data || !@fields
      raise "Invalid data or fields (was nil)"
    elsif data.length != @fields.length
      raise "#{self.name} initialized with #{data.length} parameter(s). Should be initialized with: #{@fields.collect(&:to_s).join(',')}. Bad data was '#{data}'."
    end
  end
end
