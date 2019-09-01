module Behavior
  class Flocker < Rubyhave::Selector
    def on_initialize
      self.add_child behavior(:aquatic) if @options['aquatic']
      self.add_child behavior(:idle, @options['idle']) if @options['idle']
      self.add_child behavior(:flock, @options.slice('animation'))
      self.add_child behavior(:fly, @options.slice('animation'))
      self.add_child behavior(:idle, 'animation' => @options['animation'] || 'fly', 'force' => true)
    end
  end
end
