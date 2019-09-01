class BaseCommand
  extend Forwardable
  attr_accessor :message, :connection, :errors
  attr_reader :exception, :backtrace
  def_delegators :@connection, :zone, :player, :notify, :notify_peers, :kick, :queue_peer_messages, :queue_tracked_peer_messages, :queue_message

  def initialize(message, connection)
    @connection = connection
    @errors = []
    assign_data message
  end

  def execute
    raise 'Execute needs to be defined for this command'
  end

  def fail
    # Can be overriden to provide failure logic
  end

  def request_confirmation
    sections = [{text: self.class.confirmation_msg.call(self)}]
    player.show_dialog({ 'sections' => sections, 'actions' => 'yesno' }, true, { type: :confirmation, cmd: self })
  end

  def confirm!
    finish
  end

  def execute!
    begin
      check_admin
      check_throttle
      validate if @errors.empty?
      validate_through_zone if @errors.empty?

      if @errors.empty? && should_send?
        if self.class.confirmation_msg.present?
          request_confirmation
          log({confirm: true})
        else
          finish
        end
      end

      failure! if @errors.present?

    rescue Exception => e
      @exception = e.to_s
      @backtrace = e.backtrace.first(6)
      puts "[#{self.class}] Exception: #{@exception}, #{@backtrace.first(5)}" if Deepworld::Env.development? || Deepworld::Env.test?
    end
  end

  def finish
    execute
    process_achievements!

    log if Deepworld::Env.development?
  end

  def process_achievements!
    self.class.achievements.each { |ach| ach.check player, self}
  end

  def log(extra = {})
    return unless log = self.data_log

    data = {}
    data[:message] = "#{self.class.name.sub(/Command$/, 'C')}: #{log}"
    data[:zone] = zone.id.to_s if zone
    data[:player] = player.name if player
    data[:error] = @errors unless @errors.empty?
    data[:exception] = @exception.to_s if @exception
    data[:backtrace] = @backtrace if @backtrace
    data.merge! extra

    Game.info data
    p @backtrace if @backtrace && Deepworld::Env.development?
  end

  # Override to provide validation/anti-cheat logic, add to errors array if invalid
  def validate
  end

  def validate_through_zone
    zone.validate_command self if zone
  end

  def valid?
    @errors.blank?
  end

  def should_send?
    true
  end

  def error_and_notify(msg)
    @errors << msg
    alert msg
  end

  def alert(msg)
    player.alert msg
  end

  def failure!
    # Call failure callback
    self.fail
    # TODO: Increment command failure count
    # TODO: Kick the player when they hit the threshold
  end

  def data
    self.class.fields ? self.class.fields.map{ |f| self.send f } : nil
  end

  def data_log
    data.inspect
  end

  def achievement_data
    nil
  end

  def ident
    @ident ||= CommandDirectory::COMMANDS.invert[self.class.name]
  end

  #####
  # Reusable validations
  #####

  def self.field_length
    @field_length ||= self.fields ? self.fields.length : 0
  end

  def self.optional_field_length
    @optional_field_length ||= self.ofields ? self.ofields.length : 0
  end

  def self.all_fields
    @all_fields ||= [[self.fields] + [self.ofields]].flatten.compact
  end

  protected

  def admin?
    player.admin?
  end

  def active_admin?
    player.active_admin?
  end

  def check_admin
    if self.class.active_admin_req
      if active_admin?
        return true
      else
        @errors << "Admin mode required"
        alert "You must activate god mode to do that." if admin?
        return false
      end

    elsif self.class.admin_req
      if admin?
        return true
      else
        @errors << "Admin required"
        alert "Invalid command"
        return false
      end

    else
      true
    end
  end

  def check_throttle
    if @connection.throttle_command?(self)
      @errors << "Please wait."
    end
  end

  def get_and_validate_item!(item_id = nil)
    item_id ||= @item_id
    @item = Game.item(item_id)
    @errors << "Item #{item_id} is not valid" unless @item
  end

  def run_if_valid(method_name = nil, *args)
    return unless @errors.empty?

    if block_given?
      yield
    else
      self.send(method_name.to_sym, *args)
    end
  end

  class << self
    attr_reader :fields, :ofields
    attr_accessor :confirmation_msg, :admin_req, :active_admin_req, :throttle_level

    def data_fields(*fields)
      @fields = fields

      fields.each do |f|
        attr_accessor f.to_sym
      end
    end
    alias data_field data_fields

    def optional_fields(*fields)
      @ofields = fields

      fields.each do |f|
        attr_accessor f.to_sym
      end
    end
    alias optional_field optional_fields

    def admin_required
      self.admin_req = true
    end

    def active_admin_required
      self.active_admin_req = true
    end

    def throttle(*params)
      self.throttle_level = params unless Deepworld::Env.test?
    end

    def require_confirmation(&block)
      self.confirmation_msg = block_given? ? block : Proc.new { "Are you sure?" }
    end

    # Collect achievements for this command
    def achievements
      unless @achievements
        achs = Game.config.achievements.select{ |ach, cfg| cfg.commands and cfg.commands.include?(name[0..-8]) }.values.map(&:type).uniq
        @achievements = achs.map{ |ach| "Achievements::#{ach}".constantize.new }
      end

      @achievements
    end

  end

  def assign_data(data)
    data ||= []
    data_length = data.nil? ? 0 : data.length

    if data_length.between?(self.class.field_length, self.class.field_length + self.class.optional_field_length)
      self.class.all_fields.first(data_length).each_with_index do |f, i|
        self.send("#{f}=", data[i])
      end
    else
      if self.class.optional_field_length > 0
        msg = "between #{self.class.field_length} and #{self.class.all_fields.length}"
      else
        msg = self.class.field_length
      end

      @errors << "Expected #{msg} items: #{self.class.all_fields.collect(&:to_s).join(', ')} (got #{data})"
    end
  end
end
