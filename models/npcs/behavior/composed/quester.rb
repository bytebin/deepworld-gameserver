module Behavior
  class Quester < Rubyhave::Selector
    def on_initialize
      self.add_child behavior(:fall)
      self.add_child behavior(:dialoguer)
      self.add_child behavior(:chatter)
      self.add_child behavior(:idle, 'animation' => @options['idle_animation'])
      self.add_child behavior(:walker, 'acrophobic' => true, 'fall_animation' => @options['fall_animation'])
    end
  end
end

