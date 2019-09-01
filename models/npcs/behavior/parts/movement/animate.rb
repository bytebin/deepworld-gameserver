module Behavior
  class Animate < Rubyhave::Behavior

    def on_initialize
      @animation = @options['animation']
    end

    def behave(params = {})
      entity.animate @animation if @animation
    end

    def can_behave?(params = {})
      @animation.present?
    end
  end
end
