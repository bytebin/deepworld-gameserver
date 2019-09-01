module Minigames
  class Pandora < Base
    include Leaderboard

    attr_reader :round, :potency, :spawns

    def after_initialize
      @round = 0
      @potency = 1
      @next_action_at = 0
      @spawns = []
      @potency_bumps = { @creator_id => true }
    end

    def after_start
      update_origin_block Game.item_code('containers/pandora-open'), 1
      origin_effect 'match start'

      title = "#{@creator_name} opened Pandora's Box at #{@zone.position_description @origin}"
      subtitle = "Tap on it in the next 60 seconds to build chaos!"

      zone.players.each do |pl|
        pl.alert_profile title, subtitle
      end
    end

    def config
      @config ||= YAML.load_file(File.join(File.dirname(__FILE__), 'pandora.yml'))
    end

    # Uses by additional players increases the potency
    def use(player, params = {})
      add_participant player

      # Increase potency if in starting stage
      if @round == 0
        @potency_bumps[player.id.to_s] = true
        new_potency = @potency_bumps.size
        if new_potency != @potency
          @zone.queue_message NotificationMessage.new("#{player.name} increased Pandora's chaos level to #{new_potency}!", 11)
          @potency = new_potency
        end
      end
    end

    def title
      "Pandora"
    end

    def range
      100
    end

    def announce_join?
      false
    end

    def incubation_duration
      Deepworld::Env.production? ? 1.minute : 15.seconds
    end

    def max_round_duration
      Deepworld::Env.production? ? 8.minutes : 1.minute
    end

    def max_rounds
      (10 + @potency).clamp(10, 20)
    end

    def max_spawn_travel_distance
      50
    end

    def spawn_point(player)
      (player.position - @origin).magnitude < 30 ? super : nil
    end

    def step!(delta)
      super

      return unless active?

      # Not yet started
      if @round == 0
        if @elapsed_time > incubation_duration
          add_participants_in_range
          origin_effect 'karma sound'
          update_origin_block Game.item_code('containers/pandora-open'), 2
          next_round!
        end

      # In progress
      else
        # If we've elapsed max round duration, cancel
        if @elapsed_time - @round_started_at >= max_round_duration
          cancel!

        # Do an action if enough time has elapsed since last
        elsif @elapsed_time > @next_action_at
          action!
          @next_action_at = @elapsed_time + (0.5 + (@round * 0.05)).seconds
        end

        # Explode occasionally
        if rand < delta * 0.123
          explode
        end
      end
    end

    def action!
      add_participants_in_range

      # Spawn more entities if necessary
      spawn = @round_config['spawn']
      if spawn && spawn_key = spawn.keys.random

        # Delete key if none left, otherwise decrement
        quantity_left = spawn[spawn_key]
        if quantity_left <= 1
          spawn.delete spawn_key
        else
          spawn[spawn_key] -= 1
        end

        # Spawn one
        spawned = @zone.spawn_entity(spawn_key, @origin.x + rand(2), @origin.y - 3, nil, true)
        spawned.active_minigame = self
        spawned.behavior.react :anger, nil
        @spawns << spawned
      end

      # Teleport spawn back if they wander too far
      @spawns.each do |spawn|
        if (@origin - spawn.position).magnitude > max_spawn_travel_distance
          teleport_effect spawn.position
          spawn.position = @origin + Vector2[rand(2), -rand(3)]
          teleport_effect spawn.position
        end
      end
    end

    def next_round!
      @round += 1
      @round_started_at = @elapsed_time
      @spawns.clear

      if @round == 1
        zone.queue_message NotificationMessage.new("Pandora's Box is coming ALIVE!", 1)
      elsif @round > max_rounds
        complete!
        return
      else
        alert "Pandora wave #{@round} of #{max_rounds} is beginning!"
      end

      level = case @round
      when 1..3 then 'very easy'
      when 4..6 then 'easy'
      when 7..9 then 'medium'
      when 10..12 then 'hard'
      when 13..16 then 'very hard'
      else 'epic'
      end

      # Get round config
      @round_config = Marshal.load(Marshal.dump(self.config[level].random))

      # Increase spawn counts based on potency
      potency_divisor = @round < 10 ? 2 : 3

      if @round_config['spawn']
        (@potency / potency_divisor).times do
          spawn_key = @round_config['spawn'].keys.random
          @round_config['spawn'][spawn_key] += 1
        end
      end
    end

    def participant_died!(entity, killer = nil)
      return unless active?

      # Track kills
      if killer.is_a?(Player)
        participant = add_participant(killer)
        participant.score!
      end

      # Player
      if entity.is_a?(Player)
        # Nothing yet

      # Spawn
      else
        @spawns.delete entity
        if @spawns.blank?
          next_round!
        end
      end
    end

    def cancel!
      finish!

      @spawns.each{ |sp| sp.die! }
      zone.queue_message NotificationMessage.new("Pandora could not be contained. Better luck next time.", 1)
    end

    def complete!
      finish!

      leader_msg = @current_leader ? " #{@current_leader.name} showed mastery with #{@current_leader[:kills]} kills!" : nil
      @zone.queue_message NotificationMessage.new("Pandora has been contained!#{leader_msg}", 1)

      if @current_leader
        if player = @zone.find_player_by_id(@current_leader.id)
          Rewards::Loot.new(player, types: ['armaments', 'treasure']).reward!
          player.event! :win_pandora
        end
      end
    end

    def finish!
      origin_effect 'match end'
      update_origin_block 0, 0
      explode 8
      super
    end

    def teleport_effect(pos)
      @zone.queue_message EffectMessage.new(pos.x * Entity::POS_MULTIPLIER, pos.y * Entity::POS_MULTIPLIER, 'bomb-teleport', 4)
    end

    def explode(radius = nil)
      radius ||= 4 + rand(3)
      @zone.explode Vector2[@origin.x - 1 + rand(3), @origin.y - rand(3)], radius, nil, false, base_damage = 7, ['energy'], 'bomb-electric', [0]
    end

    def meta
      { }
    end

    def current_status
      { }
    end


    # ===== Leaderboard parts ===== #

    def score(participant)
      participant[:kills] || 0
    end

    def describe_score(amt = 0)
      amt == 1 ? 'kill' : 'kills'
    end

  end
end
