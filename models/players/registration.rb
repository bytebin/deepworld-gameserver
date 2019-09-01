module Players
  module Registration

    EMAIL_REGEX = /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i
    NAME_REGEX = /^[a-zA-Z0-9\-_.\]\[\(\)]*$/

    def registered?
      email || facebook_id
    end

    def check_registration!
      unless registered?
        lock_logout!
        queue_message EventMessage.new('playerRegistered', false)
      end
    end

    def lock_logout!
      queue_message EventMessage.new('playerLockDidChange', "Before you can log out, you must register your current account. Log in and type /register in the console to register.")
      queue_message EventMessage.new('playerNeedsRegistration', true)
    end

    def unlock_logout!
      queue_message EventMessage.new('playerLockDidChange', nil)
      queue_message EventMessage.new('playerNeedsRegistration', false)
    end

    def request_registration(skip_banner = false)
      if v3? && skip_banner
        request_email_registration
      else
        dialog = Marshal.load(Marshal.dump(Game.config.dialogs.request_registration))
        dialog.actions.reject!{ |a| a =~ /Facebook/ } unless touch?
        dialog.sections.unshift({
          'image' => "http://dl.deepworldgame.com/banners/client-register-#{small_screen? ? 'v2-tiny' : 'v1-half'}.png",
          'image_size' => small_screen? ? [450, 101] : [637, 174]
        })

        show_dialog dialog, true do |vals|
          if vals.first.match(/Facebook/)
            request_facebook_registration
          elsif vals.first.match(/email/)
            request_email_registration
          end
        end
      end
    end

    def request_facebook_registration
      queue_message EventMessage.new('playerWantsFacebookConnect', nil)
    end

    def request_email_registration(dialog = nil)
      dialog ||= Game.config.dialogs.request_email_registration
      show_dialog dialog, true do |vals|
        attempt_email_registration vals.first, vals.last
      end
    end

    def attempt_email_registration(email, password)
      email = (email || '').strip

      dialog = Marshal.load(Marshal.dump(Game.config.dialogs.request_email_registration))
      dialog.sections[1]['input']['value'] = email
      dialog.sections[2]['input']['value'] = password

      errors = {}

      if !password.is_a?(String) || password.blank?
        errors['password'] = 'Invalid password'
      elsif !(6..20).include?(password.length)
        errors['password'] = 'Password must be between 6 and 20 characters.'
      end

      if email.blank? || !(email =~ EMAIL_REGEX)
        errors['email'] = 'Invalid email address'
      end

      if errors.present?
        dialog.sections[1]['input']['error'] = errors['email'] if errors['email']
        dialog.sections[2]['input']['error'] = errors['password'] if errors['password']
        request_email_registration dialog
      else
        Player.where(email_downcase: email.downcase).callbacks(false).first do |pl|
          if pl.present?
            dialog.sections[1]['input']['error'] = "Email is already taken."
            request_email_registration dialog
          else
            complete_email_registration email, password
          end
        end
      end
    end

    def complete_email_registration(email, password)
      password_salt = Digest::SHA1.hexdigest([Time.now, rand].join)
      password_hash = Digest::SHA1.hexdigest([password, password_salt].join)

      update email: email, email_downcase: email.downcase, password_salt: password_salt, password_hash: password_hash do
        unlock_logout!
        reward_for_registration!
      end
    end

    def request_name_change(dialog = nil)
      dialog ||= Game.config.dialogs.request_name_change

      show_dialog dialog, true do |vals|
        player_name = vals.first

        errors = {}
        if !(3..20).include?(player_name.length)
          errors['playername'] = 'Name must be between 3 and 20 characters.'
        elsif !(player_name =~ NAME_REGEX) || !Deepworld::PlayerBlacklist.valid?(player_name)
          errors['playername'] = 'Invalid player name.'
        end

        if errors.present?
          dialog = Marshal.load(Marshal.dump(Game.config.dialogs.request_name_change))
          dialog.sections[0]['input']['error'] = errors['playername'] if errors['playername']
          dialog.sections[1] = {'title' => ' '} # Lil padding

          request_name_change dialog do |success|
            yield success if block_given?
          end
        else
          # Make sure it's not a duplicate name
          Player.named(player_name, fields: [:name]) do |p|
            if p.nil?
              self.update({'$set' => { name: player_name, name_downcase: player_name.normalize}, '$addToSet' => { prev_names: self.name }}, false) do
                queue_message EventMessage.new("playerNameDidChange", player_name)
                yield true if block_given?
              end
            else
              dialog = Marshal.load(Marshal.dump(Game.config.dialogs.request_name_change))
              dialog.sections[0]['input']['error'] = "That name is taken already."
              dialog.sections[1] = {'title' => ' '} # Lil padding

              request_name_change dialog do |success|
                yield success if block_given?
              end
            end
          end
        end
      end
    end

    def reward_for_registration!
      unless @rewards['registration']
        crowns = 25
        notify "You registered and earned #{crowns} crowns!", 12
        Transaction.credit self, crowns, 'registration'

        time = Time.now.to_i
        @rewards['registration'] = time
        update :'rewards.registration' => time
      end

      queue_message EventMessage.new('playerRegistered', true)
    end
  end
end
