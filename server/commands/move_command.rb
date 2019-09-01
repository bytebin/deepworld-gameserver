class MoveCommand < BaseCommand
  data_fields :x, :y, :velocity_x, :velocity_y, :direction, :target_x, :target_y, :animation

  def execute
    player.position = Vector2[@x, @y]
    player.velocity = Vector2[@velocity_x, @velocity_y]
    player.target = Vector2[@target_x, @target_y]
    player.direction = direction
    player.animation = animation
    player.last_moved_at = Time.now

    player.area_explored.union! Rect.new(player.position.x.to_i, player.position.y.to_i, 1, 1)

    if zone.add_area_explored(player, player.position)
      if player.position.y - (player.position.y % zone.chunk_size.y) > zone.surface_max  # Only count if below surface
        Achievements::ExploringAchievement.new.check(player)
        player.add_xp :explore, 'New area explored!'
      end
    end
  end

  def validate
    @errors << "Fields must be numbers" and return unless [@x, @y, @velocity_x, @velocity_y, @direction, @animation].all?{ |v| v.is_a?(Numeric) }
    @errors << "Need zone" unless zone.present?

    # Adjust for multipliers
    @x /= Entity::POS_MULTIPLIER
    @y /= Entity::POS_MULTIPLIER
    @velocity_x /= Entity::POS_MULTIPLIER
    @velocity_y /= Entity::VEL_MULTIPLIER
    @target_x /= Entity::POS_MULTIPLIER
    @target_y /= Entity::VEL_MULTIPLIER

    run_if_valid :validate_health
    run_if_valid :validate_in_bounds
    run_if_valid :validate_velocity unless player.active_admin?
    run_if_valid :validate_distance unless player.active_admin?
  end

  def validate_health
    @errors << "Must be alive to move" unless player.alive?
  end

  def validate_in_bounds
    # Out of bounds?
    if (@x < 0) || (@x > zone.size.x) || (@y < 0) || (@y > zone.size.y)
      @errors << "#{x}, #{y} position is out of bounds (#{zone.size.x}, #{zone.size.y})" and return
    end
  end

  def validate_velocity
    max_speed = player.max_speed

    # Validate velocity
    @errors << "X speed #{@velocity_x} is too fast (max is #{player.max_speed.x})" if @velocity_x.abs > max_speed.x
    @errors << "Y speed #{@velocity_y} is too fast (max is #{player.max_speed.y})" if @velocity_y.abs > max_speed.y
  end

  def validate_distance
    # Validate speed/distance
    if player.position
      diff = Vector2[@x, @y] - player.position
      move_time = ((Time.now - player.last_moved_at) * 1.25).clamp(0.25, 2.0)
      @errors << "Tried to move too far X (distance #{diff.x.abs} > max #{move_time * player.max_speed.x})" if diff.x.abs > move_time * player.max_speed.x
      @errors << "Tried to move too far Y (distance #{diff.y.abs} > max #{move_time * player.max_speed.y})" if diff.y.abs > move_time * player.max_speed.y
    end
  end

  def fail
    queue_message PlayerPositionMessage.new(player.position.x, player.position.y, player.velocity.x, player.velocity.y) if player.alive?
  end

  def data_log
    nil
  end
end
