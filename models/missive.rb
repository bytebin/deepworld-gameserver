class Missive < MongoModel
  fields [:player_id, :creator_id, :creator_name, :type, :message, :created_at, :read]

  # Creator will be the sending player, or nil for system
  def self.deliver(recipient, type, message, push_notification = false, creator = nil)
    Missive.create({
      'player_id' => recipient.id,
      'creator_id' => creator ? creator.id : nil,
      'creator_name' => creator ? creator.name : nil,
      'type' => type,
      'message' => Deepworld::Obscenity.sanitize(message),
      'created_at' => Time.now,
      'read' => false})

    if push_notification
      push_message = creator ? "#{creator.name}: #{message}" : message
      PushNotification.create(recipient, push_message)
    end
  end

  def self.query_for_players(players, date_condition, order, limit, update_unread = true, delay = false)
    if players.present?
      players = [players] unless players.is_a?(Array)
      players.each{ |pl| pl.missive_checks += 1 }
      player_condition = players.size > 1 ? { '$in' => players.map(&:id) } : players.first.id
      missives_by_player = players.inject({}){ |hash, player| hash[player.id] = []; hash }

      Missive.where('created_at' => date_condition, 'player_id' => player_condition).sort(:created_at, order).limit(limit).all do |missives|
        missives.each do |missive|
          sanitized = Deepworld::Obscenity.sanitize(missive.message)
          missives_by_player[missive.player_id] << [missive.id.to_s, missive.type || 'pm', missive.created_at.to_i, missive.creator_name, sanitized, missive.read || false]
        end

        EventMachine::add_timer(delay && !Deepworld::Env.test? ? 0.5 : 0) do
          # Send missives to client
          missives_by_player.each_pair do |player_id, missive_data|
            if missive_data.present? && player = players.find{ |pl| pl.id ==  player_id }
              player.queue_message MissiveMessage.new(missive_data)
            end
          end

          # Send counts to client
          if update_unread
            players.each do |player|
              # Increment unread count and send message if we've checked for missives at least once (via zone timer)
              if player.missive_checks > 2
                if missives_by_player[player.id]
                  new_unread_missives_count = missives_by_player[player.id].count{ |d| d[5] == false }
                  if new_unread_missives_count > 0
                    player.unread_missive_count += new_unread_missives_count
                    send_count player
                  end
                end

              # Unread count hasn't been initialized, so do query to see how many unreads exist
              else
                Missive.count(player_id: player.id, read: false) do |ct|
                  player.unread_missive_count = ct
                  send_count player
                end
              end
            end
          end

          # Call finish block
          yield missives if block_given?
        end
      end
    end
  end

  def self.mark_read(player, missive_ids)
    # Player ID is here to ensure ownership
    update_all({ _id: { '$in' => missive_ids.map{ |d| d.is_a?(String) ? BSON::ObjectId(d) : d } }, player_id: player.id }, { read: true })
    player.unread_missive_count -= missive_ids.size if player.unread_missive_count
    send_count player
  end

  def self.mark_all_read(player)
    update_all({ player_id: player.id }, { read: true })
    player.unread_missive_count = 0
    send_count player
    player.alert "All messages have been marked as read."
  end

  def self.send_count(player)
    player.queue_message MissiveInfoMessage.new('u', player.unread_missive_count || 0)
  end
end
