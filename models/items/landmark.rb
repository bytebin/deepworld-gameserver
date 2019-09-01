module Items
  class Landmark < Base

    def self.persistence_vote_threshold
      5
    end

    def use(params = {})
      return false if improper_competition_phase? || maxed_competition_votes?

      @meta.data[vote_key] ||= {}

      # If player isn't high enough level to vote, deny
      unless Deepworld::Env.development?
        if player.level < 10
          alert "Sorry, you must be level 10 or higher to vote on #{noun.last}."
          return false
        end

        # If player has voted too recently, deny (exempt in competition)
        unless competition?
          period = @player.landmark_vote_interval - (Time.now - @player.landmark_last_vote_at).to_i
          if period > 0
            alert "You must wait #{period.to_period(false, false)} before voting again."
            return false
          end
        end
      end

      # If player's own landmark, deny
      if @meta.player?(@player)
        alert "Sorry, you cannot #{verb} your own #{noun.first}."
        return false
      end

      # If player has already voted, deny
      if @meta.data[vote_key][@player.id.to_s]
        alert "You have already #{verb}d this #{noun.first}."
        return false
      end

      # Send upvote dialog
      name = competition? ? noun.first : @meta.data['n']
      @player.show_dialog({ 'actions' => 'yesno', 'sections' => [{'title' => "#{verb.capitalize} #{name}?" }] }, true, { type: :callback, object: self })

      true
    end


    # Grammar

    def noun
      competition? ? ['competition entry', 'competition entries'] : ['landmark', 'landmarks']
    end

    def verb
      nomination? ? 'nominate' : 'upvote'
    end

    def verbnoun
      nomination? ? 'nomination' : 'upvote'
    end


    # Competition stuff

    def competition?
      @item.try(:use).try(:landmark) == 'competition'
    end

    def nomination?
      competition? && @zone.competition.try(:phase) == Competition::NOMINATION
    end

    def improper_competition_phase?
      if competition?
        if competition = @zone.competition
          case competition.phase
          when Competition::ACTIVE
            Items::Owner.new(@player, item: @item, meta: @meta).use!
            return true
          when Competition::NOMINATION
            unless judge?
              alert "Nominations are in progress, come back soon to vote!"
              return true
            end
          when Competition::JUDGING
            if nomination_count < competition.nomination_threshold
              alert "This entry did not recieve enough nominations to participate in voting."
              return true
            end
          when Competition::FINISHED
            alert "The competition is finished."
            return true
          end
        end
      end

      false
    end

    def maxed_competition_votes?
      if competition? && !nomination?
        if competition = @zone.competition
          return (@player.competition_votes[competition.id.to_s] || 0) >= competition.max_votes
        end
      end

      false
    end

    def judge?
      @zone.competition && @zone.competition.judges.include?(@player.id)
    end


    # Voting

    def vote_key
      if competition?
        if nomination?
          'vn'
        else
          judge? ? 'vj' : 'v'
        end
      else
        'v'
      end
    end

    def vote_count_key
      "#{vote_key}c"
    end

    def votes_count
      @meta.data['vc'] || 0
    end

    def judge_votes_count
      @meta.data['vjc'] || 0
    end

    def nomination_count
      @meta.data['vnc'] || 0
    end

    def callback(values = nil)
      # Notify player
      if @player.v3?
        @player.alert "Thanks for your #{verbnoun}!"
      else
        @player.notify({ prompt: "Thanks for your #{verbnoun}!\n\nWant to share this #{noun.first} with your friends?", message: "How do you want to share?", share: "Check out #{@meta.data['n']} in #{@zone.name}!" }, 14)
      end

      # Add vote to meta
      @meta.data[vote_key][@player.id.to_s] = Time.now.to_i
      @meta.data[vote_count_key] = @meta.data[vote_key].size

      unless competition?
        # Set time on player so they can't vote for a bit
        @player.landmark_last_vote_at = Time.now

        # Increment votes on creator
        Player.update({ '_id' => BSON::ObjectId(@meta.player_id) }, {'$inc' => { 'landmark_votes' => 1 }}, false)

        # Bump votes for achievement
        Achievements::VotingAchievement.new.check(@player)
      end

      # Send meta info
      @zone.send_meta_block_message @meta

      # Update mod of block to 1
      @zone.update_block nil, @meta.x, @meta.y, FRONT, @item.code, 1, nil, :skip

      # Persist if competition || votes greather than threshold
      persist! if competition? || votes_count >= self.class.persistence_vote_threshold

      @player.add_xp :vote

      true
    end

    def persisted?
      @meta.data['landmark_id'].present?
    end

    def persist!
      attrs = {
        name: @meta.data['n'],
        description: %w{t1 t2 t3}.map{ |t| @meta.data[t] }.compakt.join(' '),
        votes_count: votes_count
      }

      if competition?
        attrs.merge!({
          nominations_count: nomination_count,
          judge_votes_count: judge_votes_count
        })

        # Persist player competition votes if actual voting
        unless nomination?
          competition_votes = @player.competition_votes[@zone.competition.id.to_s] || 0
          @player.update "competition_votes.#{@zone.competition.id}" => competition_votes + 1
        end
      end

      # Update
      if persisted?
        ::Landmark.update({ '_id' => BSON::ObjectId(@meta['landmark_id']) }, attrs)

      # Create
      else
        attrs.merge!({
          player_id: BSON::ObjectId(@meta.player_id),
          zone_id: @zone.id,
          competition_id: @zone.competition.try(:id),
          position: @meta.position.to_a,
          created_at: Time.now
        })

        ::Landmark.create(attrs) do |doc|
          @meta.data['landmark_id'] = doc.id.to_s
        end
      end
    end

  end
end