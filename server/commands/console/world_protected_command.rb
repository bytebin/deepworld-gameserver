# Toggle protected status on a zone
class WorldProtectedCommand < BaseCommand
  data_fields :toggle
  require_confirmation do |cmd|
    'WARNING: You cannot revert back to protected status once your world is unprotected. Are you sure you want to make it unprotected?'
  end

  include WorldCommandHelpers

  def execute
    zone.update(protection_level: parse_toggle(toggle) ? 10 : 0) do
      save_command_history!
      zone.reconnect_all!('Protected world')
    end
  end

  def validate
    run_if_valid :validate_owner
    run_if_valid :validate_unlocked
    run_if_valid :validate_toggle, toggle

    unless active_admin?
      @errors << 'Sorry, you cannot revert your world back to protected status.' if parse_toggle(toggle)
    end

    run_if_valid :validate_command_history, 1.day
  end

  def fail
    alert @errors.join(', ')
  end
end
