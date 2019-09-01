module Behavior
  class Inequality < Rubyhave::Behavior

    attr_accessor :property, :value

    def behave(params = {})
      get(@property) != @value ? Rubyhave::SUCCESS : Rubyhave::FAILURE
    end

  end
end