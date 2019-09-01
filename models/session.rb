class Session < MongoModel
  SESSION_LAPSE_INTERVAL = 5.minutes
  fields [:first, :player_id, :zone_id, :started_at, :ended_at, :duration, :range_explored, :cnt]
  attr_writer :is_new

  def self.get_current(player_id, &block)
    crit = {player_id: player_id, ended_at: {'$gte' => Time.now - SESSION_LAPSE_INTERVAL}}
    self.where(crit).sort(:ended_at, :desc).first do |session|
      yield session
    end
  end

  def self.record(player)
    summary = self.summarize(player)

    if player.current_session
      player.current_session.append(summary)
    else
      # Create the session
      summary.merge! platform: player.platform,
        version: player.current_client_version,
        ip: player.connection.ip_address

      Session.create(summary) do |obj|
        yield obj if block_given?
      end
    end
  end

  def self.summarize(player)
    summary = {
      player_id: player.id,
      zone_id: [player.zone.try(:id)],
      started_at: player.started_at,
      range_explored: 0
    }

    # Ended at
    if player.ended_at
      summary[:ended_at] = player.ended_at
      summary[:duration] = (player.ended_at - player.started_at).to_i
      summary[:cnt] = 1
    end

    # Range
    if player.area_explored && player.area_explored.width && player.area_explored.height
      summary[:range_explored] = (player.area_explored.width * player.area_explored.height).to_i
    end

    # Initial session
    if player.sessions_count == 1
      summary[:first] = true
    end

    summary
  end

  def append(summary)
    zones = [zone_id].flatten.compact
    zones << summary[:zone_id] unless zone_id.last == summary[:zone_id]

    updates = {
      zone_id: zones.flatten.compact,
      ended_at: summary[:ended_at],
      duration: (summary[:ended_at] - self.started_at).to_i,
      range_explored: summary[:range_explored] + self.range_explored,
      cnt: summary[:cnt] + (self.cnt || 0)
    }

    self.update updates
  end

  def new?
    @is_new
  end
end
