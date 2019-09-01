require 'bundler'
Bundler.require

require File.expand_path('../config/initializers/load_paths.rb', __FILE__)
LOADER = Deepworld::Loader.load!(LOAD_PATHS)

# Game server
Game = GameServer.new
Game.boot!

Kernel.exit Game.exit_code