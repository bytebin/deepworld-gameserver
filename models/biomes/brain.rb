module Biomes
  class Brain

    def initialize(zone)
      @zone = zone
      @inhibitee_code = Game.item_code('mechanical/spawner-brain')
      @last_inhibit_step = @last_invasion_time = Time.now
    end

    def load
      check_inhibitees false
    end

    def step(delta_time)
      if @zone.players_count > 0
        if Time.now > @last_inhibit_step + 1.seconds
          check_inhibitors
          @last_inhibit_step = Time.now
        end

        # Invade players randomly unless inhibited
        unless @fully_inhibited
          if Time.now > @last_invasion_time + invasion_interval
            @zone.invasion.invade! @zone.players.random
            @last_invasion_time = Time.now
          end
        end

      # If no players in world, reset invasion time so it's slightly delayed when players enter
      else
        @last_invasion_time = Time.now
      end
    end



    # Inhibitors

    def check_inhibitors
      # If inhibitor is powered and near evoker, activate
      @zone.all_indexed_meta_blocks(:inhibitor).each do |inhibitor|
        if @zone.peek(inhibitor.x, inhibitor.y, FRONT)[1] == 1
          inhibitees = @zone.meta_blocks_within_range(inhibitor.position, 10, @inhibitee_code)
          if inhibitees.present?
            destroy_inhibitees inhibitees.values + [inhibitor]

            # Try to get player who placed inhibitor
            if player = inhibitor.get_player
              msg = inhibitees.size > 1 ? "You inhibited #{inhibitees.size} evokers!" : "inhibited a evoker!"
              player.alert msg
              player.event! :inhibit
              player.notify_peers "#{player.name} #{msg}.", 11
              inhibitees.size.times {
                player.add_xp :inhibitor
                Achievements::InsurrectionAchievement.new.check(player)
              }
            end

            check_inhibitees
          end
        end
      end
    end

    def destroy_inhibitees(meta_blocks)
      meta_blocks.each do |meta_block|
        @zone.update_block nil, meta_block.x, meta_block.y, FRONT, 0
        @zone.explode Vector2[meta_block.x, meta_block.y], 5, nil, true, 5, ['crushing', 'electric'], 'bomb-electric'

        # Delayed explosions
        (2..5).random.to_i.times { @zone.add_block_timer meta_block.position, (0..2).random.seconds, ['bomb-electric', 4] }
        (2..5).random.to_i.times { @zone.add_block_timer meta_block.position, (1..5).random.seconds, ['bomb-electric', 3] }
      end
    end

    def check_inhibitees(alert = true)
      @fully_inhibited = @zone.find_items(@inhibitee_code).blank?
      if @fully_inhibited && alert
        @zone.queue_message NotificationMessage.new("All evokers have been inhibited!", 1)
      end
    end



    # Invasions

    def invasion_interval
      10.minutes / @zone.players_count
    end

  end
end
