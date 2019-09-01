module Behavior
  class Equality < Rubyhave::Behavior

    attr_accessor :property, :value

    def behave(params = {})
      get(@property) == @value ? Rubyhave::SUCCESS : Rubyhave::FAILURE
    end

  end
end