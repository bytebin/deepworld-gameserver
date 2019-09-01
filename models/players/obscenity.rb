module Players
  module Obscenity

    THRESHOLD = 9
    THRESHOLD_PERIOD = 60*60

    def track_obscenity!
      damage_for_obscenity!
      increment_obscenity 1.0
    end

    def damage_for_obscenity!
      damage! 1.0, 'fire', nil, true
    end

    def increment_obscenity(amount)
      @obscenity += amount

      # If above threshold, penalize with muting
      if !muted && !muted_until
        if @obscenity > THRESHOLD
          @obscenity_penalties += 1
          duration = [15.minutes, 30.minutes, 1.hour, 2.hours, 3.hours, 4.hours, 8.hours, 12.hours][@obscenity_penalties - 1] || 24.hours

          update muted: true, muted_until: Time.now + duration, obscenity_penalties: @obscenity_penalties do
            show_modal_message Game.config.dialogs.obscenity.penalty.sub(/\$\$/, duration.to_period(false, false))
          end

        # Otherwise, if nearing threshold and we haven't been warned before, warn
        elsif !@hints['obscenity'] && @obscenity > THRESHOLD * 0.6
          show_modal_message Game.config.dialogs.obscenity.warning
          ignore_hint 'obscenity'
        end
      end
    end

    def step_obscenity(time)
      amount = time / THRESHOLD_PERIOD * THRESHOLD
      @obscenity -= amount
      @obscenity = 0 if @obscenity < 0

      # If currently muted until a certain time, check if we've surpassed it
      if muted && muted_until && Time.now > muted_until
        update muted: false, muted_until: nil, obscenity: 0 do
          show_modal_message Game.config.dialogs.obscenity.released
        end
      end
    end

  end
end