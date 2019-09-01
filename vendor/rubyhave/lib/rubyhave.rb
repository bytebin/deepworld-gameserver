# Sequence
# Loops
# Random
# Selector
# Decorator
# - Filter (counter, loop, timer)
# Actions
# Conditions

require "rubyhave/version"
require "rubyhave/behavior"
require "rubyhave/composite"
require "rubyhave/sequence"
require "rubyhave/selector"
require "rubyhave/behavior_tree"

module Rubyhave
  class << self
    attr_reader :behaviors
    attr_reader :configuration
  end

  unless defined? SUCCESS
    # Status codes
    SUCCESS = 1
    FAILURE = 2
    RUNNING = 3
  end

  def self.configure(path_or_hash)
    data = path_or_hash.is_a?(Hash) ? path_or_hash : self.load_configuration_file(path_or_hash)

    self.configure! data
  end

  private

  def self.load_configuration_file(path)
    raise "Configuration file #{path} does not exist" unless File.exists? path
    YAML.load_file path
  end

  def self.configure!(config)
    @configuration = config

    self.register_behaviors
  end

  def self.register_behaviors
    raise "Behaviors must be defined in the rubyhave configuration" unless @configuration['behaviors']

    @behaviors = {}

    self.configuration['behaviors'].each_pair do |key, name|
      raise "Behavior #{name} is undefined" unless klass = self.try_const(name)

      @behaviors[key.strip.to_sym] = klass
    end
  end

  # Borrowed and modified from activesupport
  def self.try_const(klass)
    names = klass.split('::')
    names.shift if names.empty? || names.first.empty?

    constant = Object
    names.each do |name|
      if constant.const_defined?(name)
        constant = constant.const_get(name)
      else
        return nil
      end
    end

    constant
  end
end