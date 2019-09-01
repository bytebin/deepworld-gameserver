class BlocksIgnoreCommand < BaseCommand
  data_fields :indexes

  def execute
    player.remove_active_indexes indexes
  end

  def data_log
    nil
  end
end