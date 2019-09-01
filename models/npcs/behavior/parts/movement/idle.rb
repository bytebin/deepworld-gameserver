module Behavior
  class Idle < Rubyhave::Behavior

    def on_initialize
      @delay = @options['delay'] || 60
      @duration = @options['duration'] || @delay
      @random = @options['random'] || 0.5
      @animation = [*@options['animation'] || 0]
      @force = @options['force']
      @grounded = @options['grounded'] ? Vector2[@options['grounded'][0], @options['grounded'][1]] : nil
      @flee = @options['flee']

      @idle = false
      @until = next_until(rand)
      @animation_set_until = Time.now
    end

    def behave
      if can_idle?
        if Ecosystem.time > @until
          @idle = !@idle
          @until = next_until
        end
      else
        @idle = false
      end

      if @idle || @force
        if Ecosystem.time > @animation_set_until
          @current_animation = @animation.random
          @animation_set_until = Ecosystem.time + (1..2).random
        end

        entity.move = Vector2[0, 0]
        entity.animate @current_animation
        entity.direction *= -1 if rand < 0.001
        Rubyhave::SUCCESS
      else
        Rubyhave::FAILURE
      end
    end

    def next_until(lerp = 1.0)
      dur = (@idle ? @duration : @delay) * lerp
      Ecosystem.time + (dur + (dur * rand(@random)))
    end

    def can_idle?
      grounded? && !flee?
    end

    def grounded?
      !@grounded || entity.blocked?(@grounded.x, @grounded.y)
    end

    def flee?
      !@flee || entity.active_attackers.present?
    end

  end
end
