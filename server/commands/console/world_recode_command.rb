# Console command: generate a new code for a zone
class WorldRecodeCommand < BaseCommand
  include WorldCommandHelpers

  def execute
    zone.recode! do |code|
      if code.present?
        alert "Your world entry code has been changed to #{code}."
      else
        alert "Unable to change the entry code, please try again."
      end
    end
  end

  def validate
    run_if_valid :validate_owner
    run_if_valid :validate_unlocked
  end

  def fail
    alert @errors.join(', ')
  end
end
