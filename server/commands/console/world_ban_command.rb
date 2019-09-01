class WorldBanCommand < BaseCommand
  include WorldCommandHelpers

  data_fields :bannee_name, :duration

  def execute
    if pl = zone.find_player(bannee_name)
      attempt_ban! pl
    else
      Player.named(bannee_name) do |pl|
        attempt_ban! pl
      end
    end
  end

  def validate
    run_if_valid :validate_owner
    run_if_valid :validate_unlocked

    @errors << "Player name cannot be blank." if bannee_name.blank?
    @errors << "Duration must be between 1 and 1000 minutes" unless (1..1000).include?(duration.to_i) || duration == 'forever'
  end

  def fail
    alert @errors.join(', ')
  end


  private

  def attempt_ban!(bannee)
    if bannee
      if duration == 'forever'
        if zone.meta_blocks_with_player(bannee).any?{ |mb| mb.field && mb.field > 0 }
          alert "Sorry, player '#{bannee_name}' has protected items in this world and cannot be permabanned."
        elsif zone.ban!(bannee, 100.years.to_i)
          alert "#{bannee.name} permabanned."
        end
      elsif zone.ban!(bannee, duration.to_i * 60)
        alert "#{bannee.name} banned for #{duration} minute(s)."
      end
    else
      alert "Player '#{bannee_name}' not found"
    end
  end

end