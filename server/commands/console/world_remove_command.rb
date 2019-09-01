# Console command: Remove a player from the zone members
class WorldRemoveCommand < BaseCommand
  include WorldCommandHelpers

  data_fields :name

  def execute
    Player.named(name) do |player|
      if player
        if player.admin?
          alert "#{name} is an admin and cannot be removed."
        else
          zone.remove_member(player) do
            alert "#{name} has been removed."
          end
        end
      else
        alert "Player #{name} not found."
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
