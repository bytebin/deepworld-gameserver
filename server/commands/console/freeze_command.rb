class FreezeCommand < BaseCommand
  admin_required
  data_fields :seconds

  def execute
    zone.frozen_until = Time.now + seconds.to_i
    alert "Frozen for #{seconds} seconds!"
  end

end
