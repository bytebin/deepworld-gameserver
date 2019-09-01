module Behavior
  class Flyer < Rubyhave::Selector
    def on_initialize
      blockable = @options['blockable'].nil? ? true : @options['blockable']
      opts = @options.slice('animation').merge('blockable' => blockable)
      self.add_child behavior(:idle, @options['idle']) if @options['idle']
      self.add_child behavior(:fly_toward, opts)
      self.add_child behavior(:fly, opts)
    end
  end
end
