class EvokeCommand < BaseCommand
  data_fields :evokee_name

  def execute
    zone.invasion.invade! @evokee_player
    alert "Commencing evocation!"
  end

  def validate
    @evokee_player = zone.find_player(evokee_name)

    if zone.machine_exists?(player, 'spawner')
      if @evokee_player
        @errors << "Insufficient priveleges." unless zone.machine_allows?(player, 'spawner', 'evoke')

        if zone.invasion.last_invasion_at && Time.now - zone.invasion.last_invasion_at < 5.minutes && !player.admin?
          @errors << "You must wait 5 minutes between invasions."
        end
      else
        @errors << "Unknown player."
      end
    else
      @errors << "No mass spawner machine is operational in this world."
    end

    p "invade #{@errors}"
  end

  def fail
    alert @errors.first
  end

end
