class KillCommand < BaseCommand
  admin_required
  data_fields :name

  def execute
    if name == 'all'
      zone.entities.values.select{ |e| e.ilk > 0 }.each{ |e| e.die! }
    end
  end
end