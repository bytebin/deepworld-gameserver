class WorldEnterCommand < BaseCommand
  include WorldCommandHelpers

  data_fields :code

  def execute
    ZoneEntryCommand.new([code], player.connection).execute!
  end

end
