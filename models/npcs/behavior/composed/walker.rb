module Behavior
  class Walker < Rubyhave::Selector
    def on_initialize
      @options['jump']       ||= 2
      @options['acrophobic'] ||= false

      self.add_child behavior(:idle, @options['idle']) if @options['idle']
      self.add_child behavior(:walk, 'animation' => @options['walk_animation'])
      self.add_child behavior(:jump) if @options['jump']
      self.add_child behavior(:bob)
      self.add_child behavior(:fall, 'animation' => @options['fall_animation'])
      self.add_child behavior(:turn)
    end

    def react(message, params)
      if message == :anger && !@angry
        parent.add_child behavior(:follow)
        @angry = true
      end
    end
  end
end
