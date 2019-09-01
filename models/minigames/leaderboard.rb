module Minigames

  # ===== Track leaders based on a #score method ===== #

  module Leaderboard

    def step_leaderboard(force = false)
      if force || !@next_update || Time.now > @next_update
        update_leaderboard
        @next_update = Time.now + 5.seconds
      end
    end

    def current_leaderboard
      @participants.values.sort_by do |participant|
        -participant.score
      end
    end

    def update_leaderboard
      leaderboard = current_leaderboard

      # Only update if anyone has scored yet
      if leaderboard[0].score > 0
        # Determine leaderboard ranks
        all_scores = leaderboard.map(&:score)
        leaderboard.each do |participant, idx|
          first_score_index = all_scores.index(participant.score)
          is_tied = all_scores.count{ |s| s == participant.score } > 1
          participant.leaderboard_position! first_score_index, is_tied
        end

        # Track if there is a new leader
        leader = leaderboard[0]
        if leader != @current_leader && leader.score != @current_leader_score
          new_leader leader
        end
      end
    end

    def new_leader(participant)
      @current_leader = participant
      @current_leader_score = participant.score
      if @participants.size > 1
        notify "#{participant.name} took the lead with #{participant.describe_score}!", 11
      end
    end

    def finish_with_leaderboard!
      leaderboard = current_leaderboard
      if leaderboard[0].score > 0
        winners = leaderboard.select{ |l| l.score == leaderboard[0].score }

        # Single winner
        if winners.size == 1
          notify_dual "#{winners[0].name} won with #{winners[0].describe_score}!"

        # Multiple winners
        else
          notify_dual "#{winners.size}-way tie! #{winners.map(&:name).to_sentence} won with #{winners[0].describe_score}!"
        end
      else
        notify_dual "Nobody scored any points this round. Better luck next time!"
      end
    end

  end

end
