class TeleportCommand < BaseCommand
  data_fields :destination

  def execute
    # x/y position
    if @destination_pos
      player.move! Vector2[@destination_pos[0], @destination_pos[1]]

    # Player destination
    elsif @destination_player
      player.teleport! @destination_player.position, false

    # Plaque destination
    elsif @destination_plaque
      player.teleport! @destination_plaque.position, false

    end
  end

  def validate
    @destination_player = zone.find_player(destination)
    @destination_plaque = zone.indexed_meta_blocks[:plaque].values.find{ |pl| pl['n'].try(:downcase) == destination.downcase }
    @destination_pos = destination.match(/^\d+\s\d+$/) ? destination.split(' ').map(&:to_i) : nil

    if zone.machine_exists?(player, 'teleport')
      if @destination_player
        @errors << "Insufficient priveleges." unless zone.machine_allows?(player, 'teleport', 'tp_player')
      elsif @destination_plaque
        @errors << "Insufficient priveleges." unless zone.machine_allows?(player, 'teleport', 'tp_plaque')
      elsif @destination_pos
        @errors << "Unknown player or destination." unless player.admin?
      else
        @errors << "Unknown player or destination."
      end
    else
      @errors << "No mass teleportation machine is operational in this world."
    end
  end

  def fail
    alert @errors.first
  end

end
