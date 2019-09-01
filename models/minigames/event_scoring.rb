module Minigames

  # ===== Event-based scoring & restrictions ===== #

  module EventScoring

    def initialize_event(options)
      if copy_from = options["copy_from"]
        options.merge! copy_from.attributes_hash.stringify_keys
      end

      @scoring_event = map_scoring_event(options["scoring_event"])
      @range = map_range(options["range"])
      @countdown_duration = options["countdown_duration"].to_i
      @duration = options["duration"].to_i

      @tool_restriction = options["tool_restriction"].to_i
      @block_restriction = options["block_restriction"].to_i
      @entity_restriction = options["entity_restriction"].to_i
      @max_deaths = options["max_deaths"].to_i
      @natural = options["natural"].downcase

      extend "Minigames::EventScoring::#{@scoring_event.to_s.camelize}Scorer".constantize
    end

    def scoring_event
      @scoring_event
    end

    def tool_restriction
      @tool_restriction
    end

    def tool_restriction_item
      @tool_restriction > 0 ? Game.item(@tool_restriction) : nil
    end

    def block_restriction
      @block_restriction
    end

    def block_restriction_item
      @block_restriction > 0 ? Game.item(@block_restriction) : nil
    end

    def entity_restriction
      @entity_restriction
    end

    def entity_restriction_config
      @entity_restriction > 0 ? Game.entity(@entity_restriction) : nil
    end

    def natural
      @natural
    end


    # ===== Scorers ===== #

    module BlocksMinedScorer
      def score_for_player_event(participant, event, data)
        if event == :mine &&
          position_within_range?(participant.player.last_mining_position) &&
          (block_restriction == 0 || block_restriction == data.code) &&
          (tool_restriction == 0 || tool_restriction == participant.player.current_item) &&
          (natural == "all" || (natural == "natural" && participant.player.last_mining_natural) || (natural == "unnatural" && !participant.player.last_mining_natural))
          participant.score!
        end
      end

      def describe_score(score)
        "#{'block'.pluralize score} mined"
      end
    end

    module BlocksPlacedScorer
      def score_for_player_event(participant, event, data)
        if event == :place &&
          participant_within_range?(participant) &&
          (block_restriction == 0 || block_restriction == data.code)
          participant.score!
        end
      end

      def describe_score(score)
        "#{'block'.pluralize score} placed"
      end
    end

    module ItemsCraftedScorer
      def score_for_player_event(participant, event, data)
        if event == :craft &&
          participant_within_range?(participant) &&
          (block_restriction == 0 || block_restriction == data.code)
          participant.score!
        end
      end

      def describe_score(score)
        "#{'item'.pluralize score} crafted"
      end
    end

    module PlayersKilledScorer
      def score_for_player_event(participant, event, data)
        if event == :kill &&
          data.is_a?(Player) &&
          data != participant.player &&
          position_within_range?(data.position) &&
          (tool_restriction == 0 || tool_restriction == participant.player.current_item)
          participant.score!
        end
      end

      def describe_score(score)
        "#{'player'.pluralize score} killed"
      end
    end

    module MobsKilledScorer
      def score_for_player_event(participant, event, data)
        if (event == :kill || event == :kill_spawn) &&
          position_within_range?(data.position) &&
          (tool_restriction == 0 || tool_restriction == participant.player.current_item) &&
          (entity_restriction == 0 || entity_restriction == data.config.code) &&
          (natural == "all" || (natural == "natural" && !data.spawned) || (natural == "unnatural" && data.spawned))
          participant.score!
        end
      end

      def describe_score(score)
        "#{'mob'.pluralize score} killed"
      end
    end




    private

    def map_scoring_event(val)
      { "Blocks mined" => :blocks_mined, "Blocks placed" => :blocks_placed, "Items crafted" => :items_crafted,
        "Players killed" => :players_killed, "Mobs killed" => :mobs_killed,
        "blocks_mined" => :blocks_mined, "blocks_placed" => :blocks_placed, "items_crafted" => :items_crafted,
        "players_killed" => :players_killed, "mobs_killed" => :mobs_killed }[val]
    end

    def map_range(val)
      val.is_a?(Fixnum) ? val :
        { "Micro" => 5, "Regular" => 15, "Large" => 30, "Mega" => 60, "Giga" => 120, "World" => 9999 }[val]
    end

  end

end
