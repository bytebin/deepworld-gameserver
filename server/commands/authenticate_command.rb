class AuthenticateCommand < BaseCommand
  data_fields :version, :name, :auth_token
  optional_fields :details

  def execute
    if connection.player
      kick("Player already authenticated.", false)
      return
    end

    # Attempt authentication
    Player.named(name, callbacks: false) do |player|
      if player && player.auth_tokens && player.auth_tokens.include?(auth_token)
        if has_required_version?(player)
          # Wire up the player and connection
          player.connection = connection
          player.current_client_version = version
          player.is_initial_session = details && !!details["initial"]
          connection.player = player
          player.after_initialize
          player.fetch_guild {|g| register!}

        # Old version
        else
          kick("Please update your game client.\n(Version #{required_version(player).to_s} is required)", false)
        end
      else
        kick('Authentication failure.', false)
      end
    end
  end

  def has_required_version?(player)
    Versionomy.parse(version) >= Versionomy.parse(required_version(player))
  end

  def required_version(player)
    if version && player.platform
      if cfg = Game.config.client_version
        plat = version[0] == '3' ? 'Unity' : player.platform

        cfg.each_pair do |matcher, ver|
          if plat =~ /#{matcher}/
            return ver
          end
        end

        if ver = cfg['default']
          return ver
        end
      end
    end

    self.class.default_required_version
  end

  def register!
    Game.register_player player
  end

  def data_log
    [version, name, 'filtered']
  end

  def self.default_required_version
    '2.3.4'
  end
end
