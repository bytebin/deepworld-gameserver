module Players
  class Invite

    UPGRADES = ['arctic', 'desert', 'deep', 'hell', 'brain']
    INVITES_PER_UPGRADE = 3

    def initialize(responder, inviter_id)
      @responder = responder
      @inviter_id = inviter_id
    end

    def respond!
      criteria = { player_id: @inviter_id, invitee_fb_id: @responder.facebook_id }

      ::Invite.where(criteria).all do |invites|
        if invites.present? && invites.none?{ |inv| inv.responded }
          ::Invite.update_all(criteria, { 'responded' => true }) do
            # Notify
            @responder.alert "You sent #{invites.first.player_name} an unlock!"

            # Find inviter and add responder ID to responses set
            Player.update({ _id: @inviter_id }, { '$addToSet' => { 'invite_responses' => @responder.id }}, false) do |pl|
              Player.where(_id: @inviter_id).callbacks(false).fields(:name, :invite_responses, :upgrades).first do |inviter|

                # Count inviter's total number of responses and determine if any upgrades are now available
                if progress = self.class.upgrade_progress(inviter)

                  # Add upgrade
                  if progress.last == 0
                    Player.update({ _id: @inviter_id }, { '$addToSet' => { 'upgrades' => progress.first }}, false)
                  end

                  # Create alert for player
                  Missive.create({
                    'player_id' => inviter.id,
                    'creator_id' => @responder.id,
                    'creator_name' => @responder.name,
                    'type' => 'invr',
                    'message' => self.class.response_message(inviter, @responder),
                    'created_at' => Time.now,
                    'read' => false
                  })
                end
              end
            end
          end
        end
      end
    end

    def self.upgrade_progress(inviter)
      return nil if inviter.invite_responses.blank?

      invite_count = inviter.invite_responses.size
      next_upgrade = UPGRADES[(invite_count.to_f / INVITES_PER_UPGRADE).ceil.to_i - 1]
      return nil if next_upgrade.nil?

      progress = invite_count % INVITES_PER_UPGRADE
      [next_upgrade, progress]
    end

    def self.response_message(inviter, responder)
      msg = "#{responder.name} responded to your invite."
      progress = upgrade_progress(inviter)
      if progress.last == 0
        msg + " You now have access to the #{progress.first.capitalize} biome!"
      else
        invites_left = 3 - progress.last
        msg + " You're now only #{invites_left} invite#{'s' if invites_left != 1} away from unlocking the #{progress.first.capitalize} biome!"
      end
    end

  end
end