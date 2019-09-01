class HeartbeatCommand < BaseCommand
  data_fields :latency, :command_latency

  def execute
    player.last_heartbeat_at = Time.now
    player.zone.last_activity_at = Time.now
    player.latency = latency > 0 ? latency : nil
    player.command_latency = command_latency > 0 ? command_latency : nil
    queue_message HeartbeatMessage.new(zone.run_time.to_f)
  end

  def data_log
    nil
  end
end