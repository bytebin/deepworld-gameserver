module Minigames
  class Custom < Base
    include Leaderboard
    include EventScoring

    def initialize(zone, origin, creator, options = nil)
      initialize_event options
      @timedown_minute = (duration / 60.0).ceil.to_i
      super
    end

    def subtitle
      tool_title = tool_restriction_item ? " using a #{tool_restriction_item.title.downcase}" : ""
      block_title = block_restriction_item ? block_restriction_item.title.downcase.pluralize : "blocks"
      entity_title = entity_restriction_config ? entity_restriction_config.title.downcase.pluralize : "mobs"

      case scoring_event
      when :blocks_mined
        "Mine #{block_title}#{tool_title}"
      when :blocks_placed
        "Place #{block_title}"
      when :items_crafted
        "Craft #{block_title}"
      when :players_killed
        "Kill other players#{tool_title}"
      when :mobs_killed
        "Kill #{entity_title}#{tool_title}"
      end
    end

    def step!(delta)
      super
      add_participants_in_range

      unless counting_down?
        time = time_remaining
        if time >= 40
          timedown_minute = (time_remaining / 60.0).ceil.to_i
          if timedown_minute != @timedown_minute
            notify "#{timedown_minute} #{'minute'.pluralize timedown_minute} left."
            @timedown_minute = timedown_minute
          end
        elsif time > 0
          if time.to_i == 10 && !@timedown_final
            notify "10 seconds left!"
            @timedown_final = true
          end
        else
          finish!
        end
      end
    end

    def finish!
      super
      finish_with_leaderboard!
      persist!
    end

    def persist!
      code = Deepworld::Token.generate(6)
      MinigameRecord.where(code: code).first do |c|
        if c.blank?
          persist_with_code! code
        else
          persist_with_code! Deepworld::Token.generate(7)
        end
      end
    end

    def persist_with_code!(code)
      MinigameRecord.create server_id: @zone.server_id,
        code: code,
        player_id: @creator_id,
        zone_id: @zone.id,
        created_at: Time.now,
        position: @origin.to_a,
        scoring_event: scoring_event.to_s,
        range: range,
        countdown_duration: countdown_duration,
        duration: duration,
        tool_restriction: tool_restriction,
        block_restriction: block_restriction,
        entity_restriction: entity_restriction,
        max_deaths: max_deaths,
        natural: natural,
        leaderboard: current_leaderboard.map{ |l| [l.id, l.score] }

      creator.notify "Your minigame was saved with code #{code}", 11 if creator
      if meta = zone.get_meta_block(@origin.x, @origin.y)
        meta["mini"] = code
      end
    end

    def meta
      { 'r' => range }
    end

  end
end
