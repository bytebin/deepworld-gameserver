module Behavior
  class Crawler < Rubyhave::Selector
    def on_initialize
      stuck = behavior(:stuck)
      3.times.each { stuck.add_child behavior(:fall) }

      self.add_child stuck
      self.add_child behavior(:idle, @options['idle']) if @options['idle']
      self.add_child behavior(:bob)
      self.add_child behavior(:walk, 'animation' => @options['walk_animation'])
      self.add_child behavior(:climb)
      self.add_child behavior(:turn)
      self.add_child behavior(:climb)
      self.add_child behavior(:fall, 'animation' => @options['fall_animation'])
    end

    def react(message, params)
      if message == :anger && !@angry
        parent.add_child behavior(:follow)
        @angry = true
      end
    end
  end
end

