module Minigames
  class Participant
    attr_reader :minigame, :id, :name
    attr_accessor :score, :deaths

    def initialize(minigame, player)
      @minigame = minigame
      @id = player.id.to_s
      @name = player.name
      @score = @deaths = 0
      @data = {}
      @next_message_time = Time.now
    end

    def [](name)
      @data[name]
    end

    def []=(name, val)
      @data[name] = val
    end

    def step!(delta)
      send_next_message
    end

    def score!(increment = 1)
      return if disqualified?

      @score += increment
      info_with_score
    end

    def describe_score
      "#{@score} #{@minigame.describe_score(@score)}"
    end

    def leaderboard_position!(position, is_tied)
      if position != @leaderboard_position
        @leaderboard_position = position
        @leaderboard_is_tied = is_tied
        info_with_score
      end
    end

    def info_with_score
      if @leaderboard_position
        info "You are in #{(@leaderboard_position + 1).ordinalize} place with #{@score} #{@minigame.describe_score(@score)}"
      end
    end

    def disqualify!(reason)
      @disqualified = reason

      case reason
      when :max_deaths
        player.show_dialog [{ title: 'Disqualified!', text: "You died #{minigame.max_deaths} #{'time'.pluralize minigame.max_deaths}." }]
      end
    end

    def disqualified?
      @disqualified.present?
    end

    def player
      minigame.zone.find_player_by_id(@id)
    end

    def notify(msg, status)
      player.try :notify, msg, status
    end

    def alert(msg)
      player.try :alert, msg
    end

    def info(msg, force = false)
      if msg != @last_message
        if force || ready_for_next_message?
          if pl = player
            pl.queue_message EventMessage.new("mini", msg)
            @last_message = msg
            @next_message_time = Time.now + 1.second
          end
        else
          @next_message = msg
        end
      end
    end

    def send_next_message
      if @next_message && ready_for_next_message?
        info @next_message
        @next_message = nil
      end
    end

    def ready_for_next_message?
      Time.now > @next_message_time
    end

    def finish!
      player.try :end_minigame
      info ""
    end

  end
end
