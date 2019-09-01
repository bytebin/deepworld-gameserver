module Players
  module Social

    def follow(followee)
      raise "Followee can't be nil" unless followee

      unless followees.include?(followee.id)
        update({'$addToSet' => { followees: followee.id }}, false) do
          queue_message FollowMessage.new(followee.name, followee.id.to_s, 0, true)
        end
      end

      followee.followers ||= []
      unless followee.followers.include?(self.id)
        followee.update({'$addToSet' => { followers: self.id }}, false) do
          followee.queue_message FollowMessage.new(self.name, self.id.to_s, 1, true) if followee.connection
        end
      end
    end

    def unfollow(followee)
      raise "Followee can't be nil" unless followee

      if followees.include?(followee.id)
        update({'$pull' => { followees: followee.id }}, false) do
          queue_message FollowMessage.new(followee.name, followee.id.to_s, 0, false)
        end
      end

      if followee.followers.include?(self.id)
        followee.update({'$pull' => { followers: self.id }}, false) do
          followee.queue_message FollowMessage.new(self.name, self.id.to_s, 1, false) if followee.connection
        end
      end
    end

    def follows?(player)
      followees.include?(player.id)
    end

    def followed?(player)
      followers.include?(player.id)
    end

    def send_initial_social_messages
      # Send initial follow info
      Player.get(followees) do |fol|
        queue_message FollowMessage.new(fol.map{ |f| [f.name, f.id.to_s, 0, true] }) if fol.present?

        Player.get(followers) do |fol|
          queue_message FollowMessage.new(fol.map{ |f| [f.name, f.id.to_s, 1, true] }) if fol.present?
          queue_message EventMessage.new('socialInfoReady', nil)
          send_players_online_message
        end
      end
    end

  end
end