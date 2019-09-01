# Console command: Add a player to the zone members
class WorldAddCommand < BaseCommand
  include WorldCommandHelpers

  data_fields :name

  def execute
    Player.named(name) do |invitee|
      if invitee
        zone.add_member(invitee) do
          message = "#{player.name} has added you as a member of #{zone.name}! Click the world search button and then 'Personal' > 'Member' to visit."
          Missive.deliver(invitee, 'sys', message, true, nil)

          alert "#{name} has been added."
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
