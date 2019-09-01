class EntryCommand < BaseCommand
  data_fields :number

  def execute
    player.teleport! @entry.position, false, true
    player.alert Competition.entry_title(@entry)
  end

  def validate
    if !zone.competition
      error_and_notify 'Entries only exist in competition worlds.'
      return
    end

    @number = @number.to_i

    unless (1..zone.competition.last_entry).include?(@number)
      error_and_notify "Entry must be a number between 1 and #{zone.competition.last_entry}."
      return
    end

    @entry = zone.competition.entries.find{ |e| e['entry'] == @number }
    error_and_notify "Couldn't find entry ##{@number}." unless @entry
  end

end
