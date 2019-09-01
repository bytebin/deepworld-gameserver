class FollowCommand < BaseCommand
  data_fields :recipient, :is_following

  def execute
    if followee = zone.find_player(recipient)
      follow followee
    else
      Player.where(name_downcase: recipient.downcase).fields([:_id, :followers, :name]).callbacks(false).first do |followee|
        if followee
          follow followee
        else
          alert "Couldn't find a player named #{recipient}"
        end
      end
    end
  end

  def follow(followee)
    if is_following
      player.follow followee
    else
      player.unfollow followee
    end
  end

end