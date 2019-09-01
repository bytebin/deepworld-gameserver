module Minigames
  class Deathmatch < Base
    include Leaderboard

    def after_initialize
    end

    def after_start
    end

    def meta
      { 'r' => range }
    end

    def track_kill(attacker, victim)
      attacker_participant = add_participant(attacker)
      attacker_participant.kills ||= 0
      attacker_participant.kills += 1

      victim_participant = add_participant(victim)
      victim_participant.casualties ||= 0
      victim_participant.casualties += 1
    end


    # ===== Leaderboard parts ===== #

    def score(participant)
      participant.kills
    end

    def describe_score(amt = 0)
      amt == 1 ? 'kill' : 'kills'
    end



    # ===== Lifecycle end ===== #

    def finish!
      super
      #send_status({ '$' => @kills, '!' => 2 })
    end

  end
end
