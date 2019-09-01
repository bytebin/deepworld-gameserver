# Toggle pvp on a zone
class WorldPvpCommand < BaseCommand
  data_fields :toggle

  include WorldCommandHelpers

  def execute
    zone.update({pvp: parse_toggle(toggle)}) do
      save_command_history!
      zone.reconnect_all!('PVP world')
    end
  end

  def validate
    run_if_valid :validate_owner
    run_if_valid :validate_unlocked
    run_if_valid :validate_toggle, toggle
    run_if_valid :validate_command_history, 1.day
  end

  def fail
    alert @errors.join(', ')
  end
end
