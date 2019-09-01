class SayCommand < BaseCommand
  data_fields :message

  def execute
    sanitized = Deepworld::Obscenity.sanitize(message)
    player.chat! sanitized, nil, 's', sanitized != message
    Game.log_chat zone, player, nil, message
  end

end
