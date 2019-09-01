# Mute a zone
class WorldMuteCommand < BaseCommand
  data_fields :toggle
  admin_required

  include WorldCommandHelpers

  def execute
    zone.suppress_chat = parse_toggle(toggle)
    alert "World has been #{parse_toggle(toggle) ? 'muted' : 'unmuted'}."
  end

  def validate
    run_if_valid :validate_owner unless player.admin?
  end

  def fail
    alert @errors.join(', ')
  end
end
