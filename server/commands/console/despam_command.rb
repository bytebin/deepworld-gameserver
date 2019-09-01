# Run block cleaner
class DespamCommand < BaseCommand
  admin_required

  def execute
    zone.cleaner.clean_all!
  end

end
