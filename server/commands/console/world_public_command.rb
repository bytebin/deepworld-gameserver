# Toggle public status on a zone
class WorldPublicCommand < BaseCommand
  data_fields :toggle

  include WorldCommandHelpers

  def execute
    is_private = !parse_toggle(toggle)

    options = { private: is_private }
    options[:protection_level] = 10 if zone.protection_level.blank? && !is_private

    zone.update(options) do
      save_command_history!
      zone.reconnect_all!('Public world')
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
