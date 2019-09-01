class PrivateMessageCommand < BaseCommand
  optional_fields :recipient_name, :message
  throttle 2, 10.0, 'Please wait before sending another message.'

  def execute
    if !recipient_name.is_a?(String) || recipient_name.blank?
      player.queue_message EventMessage.new('pm', '')
    elsif !message.is_a?(String) || message.blank?
      player.queue_message EventMessage.new('pm', recipient_name)
    else
      send!
    end
  end

  def send!
    Player.named(recipient_name, fields: [:name, :last_active_at, :followees, :current_client_version, :settings]) do |recipient|
      if recipient.present?
        # Require recipient to be on latest version
        if !recipient.client_version?('1.11.2')
          @errors << "#{recipient.name} cannot receive private messages yet."
          fail

        # Require recipient to follow player
        elsif !admin? && (recipient.followees.blank? || !recipient.followees.include?(player.id))
          @errors << "#{recipient.name} must follow you before you can send them private messages."
          fail
        else
          Missive.deliver(recipient, 'pm', message, true, player)
          alert "Message sent to #{recipient.name}."
        end
      else
        @errors << "Player #{recipient_name} not found."
        fail
      end
    end
  end

  def validate
    unless admin?
      max_chars = 150
      @errors << "Message must be between 1 and #{max_chars} characters" if message.is_a?(String) && message.size > max_chars
      @errors << "You cannot message yourself." if recipient_name == player.name
      @errors << "You cannot message while muted." if player.muted
    end
  end

  def fail
    alert @errors.join(', ')
  end
end
