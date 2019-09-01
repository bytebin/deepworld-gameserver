class RestartCommand < BaseCommand
  admin_required

  def execute
    Game.shutdown!
  end
end