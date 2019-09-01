module Items
  class Challenge < Base

    def use(params = {})
      persist!
    end

    def persist!
      attrs = {
        name: @meta['n'],
        description: %w{t1 t2 t3}.map{ |t| @meta[t] }.compakt.join(' '),
        xp: @meta['vc'].to_i,
        loot: @meta['loot']
      }

      # Update
      if persisted?
        ::Challenge.update({ '_id' => BSON::ObjectId(@meta['challenge_id']) }, attrs) do
          @player.alert "Challenge updated."
        end

      # Create
      else
        attrs.merge!({
          player_id: BSON::ObjectId(@meta.player_id),
          zone_id: @zone.id,
          position: @meta.position.to_a,
          created_at: Time.now
        })

        ::Challenge.create(attrs) do |doc|
          @meta['challenge_id'] = doc.id.to_s
          @player.alert "Challenge created."
        end
      end
    end

    def persisted?
      @meta['challenge_id'].present?
    end

    def destroy!
      if persisted?
        ::Challenge.remove({ '_id' => BSON::ObjectId(@meta['challenge_id']) }) do
          @player.alert "Challenge removed."
        end
      end
    end

  end
end