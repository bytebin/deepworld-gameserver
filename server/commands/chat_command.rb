class ChatCommand < BaseCommand
  data_fields :recipient_name, :message
  throttle 4, 2.0, 'Please do not spam chat.'

  def execute
    message.gsub!(/\r?\n|\r|\t/, "")
    processed_message = Deepworld::Obscenity.sanitize(message)

    # Command
    if message.match(/^\*/)
      bits = message.sub(/^\*\s*/, '').split(' ')
      process_command bits[0], bits[1..-1].join(' ')

    # Normal chat
    else
      if recipient_name
        if @recipient = zone.find_player(recipient_name)
          player.chat! processed_message, @recipient, 'p', processed_message != message
        else
          alert "Couldn't find player #{recipient_name}"
        end
      else
        player.chat! processed_message, nil, 'c', processed_message != message
      end

      # Send unstuck hint if chat matches criteria
      if message.match(/(help|halp|hlp|stuck)/)
        player.send_hint 'help-im-stuck'
      end

      # Create flag and send don't be a doofus with your password hint
      if message.match(/(u|ur|your|youre|you\'re) (pass|pasw|pazz)/)
        player.send_hint 'protect-your-password'
        player.flag! 'reason' => "mentioned 'your password' in chat", 'data' => { 'chat' => message }
      end

    end

    Game.log_chat zone, player, @recipient, message
  end

  def process_command(cmd, param)
    alert "Unknown command #{cmd}"
  end

  def validate
    @errors << "Message must be between 1 and 100 characters" if !message.is_a?(String) || message.size < 1 || message.size > 100
    # TODO check for blocked player

    validate_suppression unless player.admin?
    validate_mutings
  end

  def validate_suppression
    error_and_notify "This world has been muted." if zone.suppress_chat
  end

  def validate_mutings
    error_and_notify "You must unmute all in order to chat" if player.has_muted_all?
    error_and_notify "Your karma is too low to chat" if player.role?("cheater")
  end

  def data_log
    nil
  end
end
