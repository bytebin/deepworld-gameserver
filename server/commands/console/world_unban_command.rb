class WorldUnbanCommand < BaseCommand
  include WorldCommandHelpers

  data_fields :unbannee_name

  def execute
    Player.named(unbannee_name) do |pl|
      if pl
        zone.unban! pl
        alert "Player '#{unbannee_name}' unbanned."
      else
        alert "Player '#{unbannee_name}' not found."
      end
    end
  end

  def validate
    run_if_valid :validate_owner

    @errors << "Player name cannot be blank." if unbannee_name.blank?
  end

  def fail
    alert @errors.join(', ')
  end
end
