module Players
  module Facebook
    def debug?
      # Log to standard out in non-prod, and production (port 5000)
      !Deepworld::Env.production? || Game.port == 5000
    end

    def facebook_graph_request(url, params)
      post = params.delete(:post)

      if object = params.delete(:object)
        query = object.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join("&")
        params = { object[:type] => "http://#{Deepworld::Settings.codex}/graph?#{query}" }
      end

      params[:access_token] = @facebook_token

      url = "https://graph.facebook.com/#{url}"
      req = EventMachine::HttpRequest.new(url)

      p "Facebook params #{params}" if debug?
      post ? req.post(body: params) : req.get(query: params)
    end

    def facebook_graph(url, params, error_message = nil)
      return unless @facebook_token.present?
      p "Facebook graph: #{url} / #{params}" if debug?
      http = facebook_graph_request(url, params)
      http.errback { notify error_message if error_message }
      http.callback do
        if debug?
          p http.response_header.status
          p http.response_header
          p http.response
        end

        begin
          json = JSON.parse(http.response)
          yield json if block_given?
        rescue
          notify error_message if error_message
        end
      end
    end

    def facebook_connect(token, interactive = false)
      already_has_token = @facebook_token.present?
      @facebook_token = token
      publish_initial_graph_actions
      return if already_has_token || @facebook_id.present?

      facebook_graph 'me', {}, 'There was an error connecting to Facebook.' do |json|
        if json['id']
          Player.count(facebook_id: json['id']) do |ct|
            if ct == 0
              fb_updates = {facebook_id: json['id']}
              fb_updates[:email] = json['email'] if self.email.blank?

              update fb_updates do
                if @facebook_id
                  unlock_logout!
                  reward_for_registration!

                  # Check if we want permissions request right after connect
                  if false
                    EM.add_timer(Deepworld::Env.test? ? 0 : 3.0) do
                      if @facebook_wants_permissions_after_connect
                        request_facebook_permissions 'publish_actions'
                      end
                    end
                  end

                  # Respond to any invites
                  invite_criteria = { 'invitee_fb_id' => @facebook_id, 'linked' => false }
                  ::Invite.where(invite_criteria).all do |invites|
                    missives = invites.map do |inv|
                      invite_missive(self, inv.player_id, inv.player_name)
                    end
                    Missive.collection.insert missives

                    # Mark invites as linked via new connect
                    ::Invite.update_all(invite_criteria, { 'linked' => 'n' })
                  end
                end
              end
            else
              alert "Your Facebook account is already connected to another player." if interactive
            end
          end
        else
          alert "There was an error connecting to Facebook." if interactive
        end
      end
    end

    def facebook_permissions_changed(token)
      facebook_graph 'me/permissions', {}, 'There was an error connecting to Facebook.' do |json|
        if perms = json['data'].try(:first)
          perms = perms.select{ |k,v| v == 1 }.keys
          update facebook_permissions: perms do
            # If publish_actions, reward
            reward_for_facebook if @facebook_permissions.include?('publish_actions')
          end
        end
      end
    end

    # Creates invite documents based on facebook response URL (from client invite callback)
    # Sample URL:
    # fbconnect://success?request=710157248998563&to%5B0%5D=100002513465484&to%5B1%5D=100000585448240
    def facebook_invite(facebook_data)
      fb_ids = facebook_data.is_a?(Array) ? facebook_data : facebook_data.split('&')[1..-1].map{ |req| req.split('=')[1] }.compact
      return if fb_ids.blank?

      # See if any players currently exist with these facebook IDs
      Player.where('facebook_id' => { '$in' => fb_ids }).all do |players|
        ::Invite.where('player_id' => @id).fields('invitee_fb_id').all do |existing_invites|

          invites = []
          missives = []

          fb_ids.each do |fb_id|
            if existing_invites.none?{ |inv| inv.invitee_fb_id == fb_id }
              invite = { 'player_id' => @id, 'player_name' => @name, 'invitee_fb_id' => fb_id, 'linked' => false, 'created_at' => Time.now }

              # If any existing players match facebook ID, mark invite as linked and create a missive
              if matched_player = players.find{ |pl| pl.facebook_id == fb_id }
                invite['linked'] = 'e'
                missives << invite_missive(matched_player, id, name)
              end

              invites << invite
            end
          end

          ::Invite.collection.insert invites if invites.present?
          Missive.collection.insert missives if missives.present?
        end
      end
    end

    def publish_initial_graph_actions
      if !@published_initial_graph_actions && !zone.tutorial?
        #facebook_graph "me/deepworldgame:visit", post: true, object: { type: 'world', id: zone.id }
        @published_initial_graph_actions = true
      end
    end

    def request_facebook_actions
      if should_request_facebook_actions?
        if should_request_facebook_permissions?
          show_dialog Game.config.dialogs.facebook_permissions do |resp|
            if @facebook_id
              request_facebook_permissions 'publish_actions'
            else
              @facebook_wants_permissions_after_connect = true
              request_facebook_connect
            end
          end
          ignore_hint 'facebook-permissions'
        end

        if !@premium && @facebook_id && !@hints['facebook-invite'] && play_time > 1.hour
          show_dialog Game.config.dialogs.invite_to_upgrade, false
          ignore_hint 'facebook-invite'
        end
      end
    end

    def should_request_facebook_actions?
      touch? && !@hints_in_session.include?(:login)
    end

    def should_request_facebook_permissions?
      @hints['facebook-permissions'].blank? && play_time > 15.minutes && !facebook_permission?('publish_actions')
    end

    def facebook_permission?(perm)
      @facebook_permissions[perm].present?
    end

    def request_facebook_connect
      queue_message EventMessage.new('playerWantsFacebookConnect', nil)
    end

    def request_facebook_permissions(permissions)
      queue_message EventMessage.new('requestFacebookPermissions', permissions)
    end

    def invite_missive(player, inviter_id, inviter_name)
      msg = "#{inviter_name} needs your help to upgrade their account! Click to send them some love!"
      { 'creator_id' => inviter_id, 'player_id' => player.id, 'type' => 'inv', 'created_at' => Time.now, 'message' => msg, 'read' => false }
    end

    def reward_for_facebook
      unless @rewards['facebook']
        crowns = 25
        notify "You connected to Facebook and earned #{crowns} crowns!", 12
        Transaction.credit self, crowns, 'facebook_connect'

        time = Time.now.to_i
        @rewards['facebook'] = time
        update :'rewards.facebook' => time
      end
    end
  end
end