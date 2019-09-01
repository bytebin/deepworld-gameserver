class StatCommand < BaseCommand
  admin_required
  data_fields :key, :value

  def execute
    case key
    when 'premium'
      player.update premium: value.to_i == 1
      queue_message StatMessage.new([key, player.premium])
      return
    when 'karma' then player.karma = value.to_i
    when 'karmai'
      player.penalize_karma value.to_i.abs
      alert "Your karma is now #{player.karma}"
    when 'points' then player.points = value.to_i
    when 'crowns' then player.crowns = value.to_i
    when 'acidity' then player.zone.acidity = value
    when 'xpp'
      player.add_xp value.to_i
    when 'xp'
      lv = (2..100).find{ |lv| value < Players::Xp.xp_for_level(lv) } - 1
      player.xp = value
      player.update level: lv do |pl|
        player.send_level_message lv
        player.send_xp_message 0, player.xp
      end
    end

    queue_message StatMessage.new([key, value])
  end

  def validate
    allowed_stats = {
      'karma' => (-9999..9999),
      'karmai' => (-9999..9999),
      'points' => (0..100),
      'crowns' => (0..9999),
      'acidity' => (0..1.0),
      'xp' => (0..Players::Xp.xp_for_level(200)),
      'xpp' => (0..9999999),
      'premium' => (0..1)
    }

    @errors << "Invalid stat" unless allowed_stats[key].try(:include?, value)
  end
end
