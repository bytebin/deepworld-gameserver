# ruby-prof -f prof/`date +%s`.txt -s total deepworld.rb
# be ruby simulator.rb -n 28 -s -k 5 -t 60
# https://github.com/jclulow/terminal-heatmap

# ENV=staging be ruby simulator.rb -n 50
# ENV=staging be ruby simulator.rb -n 50 -z Awesomesauce
# be ruby simulator.rb -n 10
require 'bundler'
Bundler.require :default

ENVIRONMENTS = {
  production: {gateway: 'gateway.deepworldgame.com', gateway_port: 80},
  staging: {gateway: 'gateway-staging.deepworldgame.com', gateway_port: 80},
  development: {gateway: '127.0.0.1', gateway_port: 5001}
}

load_paths = [
  '../../server/commands/console/world_command_helpers.rb',
  '../../server/commands/console/guild_command_helpers.rb',
  '../../server/commands/base_command.rb',
  '../../server/messages/entity_message_helper.rb',
  '../../server/messages/base_message.rb',
  '../../server/commands/console/world_command_helpers.rb',
  '../../server/commands',
  '../../server/messages',
  '../../spec/support/message.rb',
  'sim_player.rb',
  'gateway.rb',
  '../../lib/vector2.rb',
  '../../lib/rect.rb',]

class OptionParser
  def self.parse
    require 'optparse'
    options = {chat: false, num_players: 1, registration_delay: 0.6, run_time: nil}

    optparse = OptionParser.new do |opts|

      opts.banner = "Usage: ENV=development ruby simulator.rb [-n --num_players number] [-z --zone zone_name]"

      opts.on( '-t', '--time time', 'Run for this many seconds') do |t|
        options[:run_time] = t.to_i
      end

      opts.on( '-n', '--num_players number', 'Number of simulated players') do |n|
        options[:num_players] = n.to_i
      end

      opts.on( '-z', '--zone zone_name', 'Zone to spawn the player in') do |z|
        options[:zone] = z
      end

      opts.on( '-k', '--clump clump_size', 'Clump size (grouping of players)') do |k|
        options[:clump] = k.to_i
      end

      opts.on( '-m', '--maximum_zones max', 'Only spawn in this max number of zones') do |m|
        options[:max_zones] = m.to_i
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end

    optparse.parse!

    options.merge!(ENVIRONMENTS[Deepworld::Env.environment.to_sym])
  end
end

class Simulator
  attr_accessor :run_at

  def initialize(options)
    @run_at = Time.now
    @zones = get_zones(options[:zone], options[:max_zones])

    EM.epoll
    EM.run do
      # EM Setup
      Signal.trap("INT")  { @quit = true }
      Signal.trap("TERM") { @quit = true }

      EM.add_periodic_timer(0.125) { quit! if @quit }
      if options[:run_time]
        EM.add_timer(options[:run_time]) do
          EM.stop_event_loop
        end
      end

      EM.error_handler do |e|
        puts "Error raised during event loop:\n#{e.message}\n#{e.backtrace.join("\n")}"
      end

      puts "[Info] Initializing players(s)..."
      initialize_players(options[:num_players], options[:registration_delay])
    end
  end

  def db
    return @db if @db

    host, port = Deepworld::Settings.mongo.hosts.first.split(':')

    @db = Mongo::Connection.new(host, port).db(Deepworld::Settings.mongo.database)
    if Deepworld::Settings.mongo.username
      auth = @db.authenticate(Deepworld::Settings.mongo.username, Deepworld::Settings.mongo.password)
    end

    @db
  end

  def get_zones(zone_name, max_zones = nil)
    if zone_name
      zone = db['zones'].find_one({name: zone_name}, {fields: [:_id, :name]})
      raise "#{zone_name} is not an existing zone in that environment." unless zone
      zones = [[zone['_id'], zone['name']]]
    else
      opts = {fields: [:_id, :name]}
      opts[:limit] = max_zones if max_zones

      zones = db['zones'].find({active: true, private: { '$ne' => true }}, opts).to_a.map{|z| [z['_id'], z['name']]}
    end

    zones
  end

  def quit!
    puts "[Info] Simulators going to sleep now..."
    delete_players!
    EventMachine::stop_event_loop
  end

  def delete_players!
    db['players'].remove({simulated_at: @run_at})
  end

  def initialize_players(player_count, delay)
    @sims = []
    to_load = player_count

    timer = EM.add_periodic_timer(1) do
      to_load -= 1

      if to_load == 0
        timer.cancel
        puts "[Info] Done loading players!"
      end

      create_player do |player|
        SimPlayer.connect!(player) {|sim| @sims << sim}
      end
    end
  end

  def create_player(options = {}, &block)
    operation = Proc.new do
      name = (Faker::Name.first_name + Faker::Name.last_name)[0..15]
      zone = @zones.random(1)

      # Salt and password for "password"
      player =
        { name: name,
          name_downcase: name.downcase.squeeze(' ').strip,
          email: "#{name}#{rand(10000)}@simulator.com",
          auth_token: SecureRandom.hex(8),
          created_at: Time.now,
          simulated_at: @run_at,
          password_hash: '80b8e3987bb13de41245e89e2674fc14321e9d98',
          password_salt: 'a62eaae9898a45f1f13786296e40542f194f091b',
          zone_id: zone[0]}.merge(options)

      db['players'].insert player
      player.merge({password: 'password'})
    end

    EM.defer(operation, block)
  end
end

raise "DO NOT run the simulator in production!" if Deepworld::Env.production?

options = OptionParser.parse
Deepworld::Loader.load!(load_paths)
Deepworld::Configuration.configure! Deepworld::Env.environment

GATEWAY = Gateway.new(Deepworld::Env.environment.to_sym)
puts "[Info] Booting Simulator\n[Info] Authentication URL: #{GATEWAY.auth_url}\n[Info] Players: #{options[:num_players]}"

Simulator.new(options)