module Minigames
  class Base

    attr_reader :creator_id, :creator_name, :zone, :origin, :started_at, :participants, :active
    alias :active? :active

    def initialize(zone, origin, creator, options = nil)
      @zone = zone
      @origin = origin
      @creator_id = creator.id.to_s if creator
      @creator_name = creator.name if creator
      @started_at = Time.now
      @participants = {}
      @options = options

      after_initialize

      if creator
        add_participant creator, false
        creator.alert_profile "You began a #{title}!", subtitle
      end
    end

    def after_initialize
    end

    def range
      @range || 999999999
    end

    def no_range?
      @range > @zone.size.x && @range > @zone.size.y
    end

    def participant_within_range?(participant)
      if pl = participant.player
        position_within_range?(pl.position)
      else
        false
      end
    end

    def position_within_range?(position)
      no_range? || Math.within_range?(origin, position, range)
    end

    def countdown_duration
      @countdown_duration || 0
    end

    def duration
      @duration || 999999999
    end

    def max_deaths
      @max_deaths || 999999999
    end

    def meta
    end

    def title
      "minigame"
    end

    def subtitle
      ""
    end

    def start!
      @active = true
      @started_at = Time.now
      @elapsed_time = 0
      @zone.minigames << self
      add_participants_in_range
      after_start
    end

    def after_start
    end

    def creator
      @zone.find_player_by_id(@creator_id)
    end


    # ===== Participants ===== #

    def add_participants_in_range
      participants = @zone.players_in_range(@origin || Vector2[0,0], self.range).select{ |p| !p.in_minigame? }
      participants.each do |player|
        add_participant player
      end
    end

    def announce_join?
      true
    end

    def announce_title
      "Joined #{title} hosted by #{@creator_name}"
    end

    def add_participant(player, announce = true)
      player.join_minigame self
      @participants[player.id.to_s] ||= Participant.new(self, player)

      if announce_join? && announce
        player.alert_profile announce_title, subtitle
      end

      @participants[player.id.to_s]
    end

    def get_participant(player)
      @participants[player.id.to_s]
    end

    def participant_players
      @participants.keys.map{ |pid| zone.find_player_by_id(pid) }.compact
    end

    def participating?(player)
      @participants[player.id.to_s].present?
    end

    def step_participants(delta)
      @participants.each_value{ |participant| participant.step! delta }
    end

    def info_all(msg)
      event = EventMessage.new("mini", msg)
      participant_players.each{ |pl| pl.queue_message event }
    end

    def player_event(player, event, data)
      if participant = get_participant(player)
        case event
        when :death
          participant.deaths += 1
          if max_deaths > 0 && participant.deaths >= max_deaths
            participant.disqualify! :max_deaths
            after_disqualification player, :max_deaths
          end
        end

        if respond_to?(:score_for_player_event)
          if !counting_down?
            score_for_player_event participant, event, data
          end
        end
      end
    end

    def after_disqualification(player, reason)
    end



    # ===== Helpers ===== #

    def notify(msg, status = 1)
      participant_players.each{ |p| p.notify msg, status }
    end

    def notify_dual(msg)
      notify msg
      notify msg, 11
    end

    def alert(msg)
      participant_players.each{ |p| p.alert msg }
    end

    def use(player, params = {})
      player.alert "Minigame in progress!"
    end

    def step!(delta)
      @elapsed_time += delta
      step_leaderboard if respond_to?(:step_leaderboard)
      step_participants delta

      if counting_down?
        countdown_second = (countdown_duration - @elapsed_time).ceil.to_i
        if countdown_second != @countdown_second
          info_all "#{countdown_second} second#{'s' if countdown_second != 1} until the game begins."
          @countdown_second = countdown_second
        end
      elsif @countdown_second
        info_all "The game has begun!"
        @countdown_second = nil
      end
    end

    def counting_down?
      @elapsed_time < countdown_duration
    end

    def skip_countdown!
      @elapsed_time = countdown_duration
    end

    def time_remaining
      duration - @elapsed_time + countdown_duration
    end

    def spawn_point(player)
      active? ? all_spawn_points.random : nil
    end

    def all_spawn_points
      ([@origin] + @zone.teleporters_in_range(@origin || Vector2[0,0], range).map(&:position)).compact
    end


    # ===== Lifecycle end ===== #

    def active?
      !!@active
    end

    def finish!
      step_leaderboard true if respond_to?(:step_leaderboard)
      @active = false

      @participants.values.each do |participant|
        participant.finish!
      end

      cleanup!
    end

    def cleanup!
      @zone.minigames.delete self
    end

    def update_origin_block(item_code, mod)
      @zone.update_block nil, @origin.x, @origin.y, FRONT, item_code, mod
    end

    def origin_effect(effect)
      @zone.queue_message EffectMessage.new(@origin.x * Entity::POS_MULTIPLIER, @origin.y * Entity::POS_MULTIPLIER, effect, 1)
    end

  end
end
