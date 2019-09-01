ENV['ENV'] = ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'

require 'bundler'
require 'rubygems'
require 'yajl'

Bundler.require(:default, :test)

# Load app and support files
require File.expand_path('../../config/initializers/load_paths.rb', __FILE__)
['spec/support', 'spec/foundries/base_foundry.rb', 'spec/foundries'].each {|p| LOAD_PATHS << p}
LOADER = Deepworld::Loader.load!(LOAD_PATHS)

include TestHelpers
include Eventually

PORT = 6969
Game = GameServer.new
DB_CONNECTIONS = []

RSpec.configure do |config|
  config.mock_with :rspec
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run_including focus: true
  config.filter_run_excluding slow: true
  config.filter_run_excluding performance: true

  require "support/test_helpers"
  require "faker"
  I18n.reload!

  config.before(:suite) do
    # Set game configuration
    config_file = File.read(File.expand_path('../data/game_configuration.json', __FILE__))

    begin
      parser = Yajl::Parser.new
      config_data = parser.parse(config_file)
    rescue
      puts "JSON parse failure #{$!.message}"
    end

    ConfigurationFoundry.create(key: 'config', type: 'config', data: config_data)

    game_thread = Thread.new { Game.boot!(PORT) }
    game_thread.abort_on_exception = true

    # Pause till the server is ready
    server_wait

    profile_start if ENV['PROFILE']
  end

  config.after(:suite) do
    clean_mongo!

    profile_stop if ENV['PROFILE']

    Game.shutdown!
  end

  config.before :each do
    clean_mongo! except: :servers
    Game.config.test = {}
  end

  config.after :each do
    # Kill all players / zones / queues
    Game.zones.values.each do |zone|
      zone.shutdown! unless zone.shutting_down_at
    end

    Game.connections.each { |z,conns| conns.each{ |c| c.close }}
    Game.connections.clear
  end
end
