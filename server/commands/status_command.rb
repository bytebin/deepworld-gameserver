class StatusCommand < BaseCommand
  data_fields :status

  def execute
    if sys = status.delete('sys')
      player.update system_info: JSON.parse(sys)
    end

    player.client_info = (player.client_info || {}).merge(status)

    unless admin?
      if status['s'].to_i > 50 || status['sm'].to_i > 50 ||
        status['h'].to_i > 20 || status['hm'].to_i > 20 ||
        status['a'] == true || status['cl'] == false ||
        status['cr'].to_i > 1000000 ||
        status['skm'].to_i > 15 || status['ske'].to_i > 15 ||
        status['h'].to_i > player.max_health+1 ||
        status['rsp'].to_i < 0 || status['rsp'].to_i > 1.7 ||
        status['clsp'].to_i < 0 || status['clsp'].to_i > 2.3 ||
        status['msp'].to_i < 0 || status['msp'].to_i > 1.8 ||
        status['swsp'].to_i < 0 || status['swsp'].to_i > 1.8 ||
        status['jump'].to_i < 0 || status['jump'].to_i > 1.5

        player.mark_cheater_at = Time.now + (10..20).random.seconds unless player.mark_cheater_at
        player.client_info["last_cheated_at"] = Time.now.to_s
      end

      if status['stat'] == "c" || status['stat'] == "ms" || status['stat'] == "f"
        player.roles << "glitch" unless player.role?("glitch")
      end
    end
  end

  def validate
    @errors << "Invalid status" if status.size > 30 || !status.values.all?{ |s| s.is_a?(Numeric) || s.is_a?(String) || s == true || s == false }
  end

end
