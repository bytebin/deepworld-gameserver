module Players
  module Karma

    def check_karma(x, y, layer, item_id)
      # Always allow mining of certain kinds of blocks (earth, etc.)
      karma_hit = Game.item(item_id.to_i).karma.to_i

      return 0 unless karma_hit <= karma_block_threshold

      owner_digest = zone.block_owner(x, y, layer)

      # Allow mining of non-owned blocks
      return 0 unless owner_digest > 0

      penalize_karma karma_hit.abs unless can_grief?(owner_digest)
    end

    def suppressed?
      !!@suppressed || role?("cheater")
    end

    def can_grief?(owner_digest)
      self.digest == owner_digest || self.follower_digest.include?(owner_digest)
    end

    def karma_threshold
      @premium ? -250 : -150
    end

    # Higher values mean player doesn't get dinged for low-karma blocks
    def karma_block_threshold
      @premium && @play_time > 2.days ? -2 : -1
    end

    def penalize_karma(amount)
      @karma -= amount

      # If above threshold, penalize with muting
      if !suppressed && !suppressed_until
        if @karma < karma_threshold
          @karma_penalties += 1
          duration = [15.minutes, 30.minutes, 1.hour, 2.hours, 4.hours, 8.hours, 1.day, 2.days, 3.days, 4.days, 5.days][@karma_penalties - 1] || 7.days

          update suppressed: true, suppressed_until: Time.now + duration, karma_penalties: @karma_penalties do
            show_modal_message Game.config.dialogs.karma.penalty.sub(/\$\$/, duration.to_period(false, false))
            notify_karma
          end

        # Otherwise, if nearing threshold and we haven't been warned before, warn
        elsif !@hints['karma'] && @karma < karma_threshold * 0.6
          show_modal_message Game.config.dialogs.karma.warning
          ignore_hint 'karma'
        end
      end
    end

    def step_karma(time)
      amount = time / 300.0
      @karma += amount if @karma < 0

      # If currently suppressed until a certain time, check if we've surpassed it
      if suppressed? && suppressed_until && Time.now > suppressed_until
        update suppressed: false, suppressed_until: nil, karma: 0 do
          show_modal_message Game.config.dialogs.karma.released
          notify_karma
        end
      end
    end

    def notify_karma
      queue_message StatMessage.new('karma', karma_description)
    end

    def karma_description(amt = nil)
      amt ||= suppressed ? -1000 : @karma
      k = Karma.config[premium ? 'premium' : 'free']['description']
      k.find{ |karma_level, description| amt >= karma_level }.try(:last) || 'Unthinkable'
    end

    def self.config
      @karma_config ||= YAML.load_file(File.expand_path('../karma.yml', __FILE__))
    end

  end
end
