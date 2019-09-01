class MutexCommand < BaseCommand
  data_fields :player_name
  optional_fields :duration

  def execute
    player.command! MuteCommand, [player_name, duration, true]
  end

end