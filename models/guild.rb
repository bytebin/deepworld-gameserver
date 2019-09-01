class Guild < MongoModel
  fields [:name, :short_name]
  fields [:zone_id, :leader_id]
  fields :position, Vector2
  fields :members, Array
  fields [:color1, :color2, :color3, :color4, :sign_color]
  fields [:sign]

  META_MAPPING = {'gn' => :name, 'gsn' => :short_name, 'c1' => :color1, 'c2' => :color2, 'c3' => :color3, 'c4' => :color4, 's' => :sign, 'sc' => :sign_color}
  OBELISK_RANGE = 10

  def validate(&block)
    @errors = []
    @errors << "Guild name must be between 3 and 20 characters." if name.nil? || name.length.clamp(3, 20) != name.length
    @errors << "Short name must be between 2 and 8 characters." if short_name.nil? || short_name.length.clamp(2, 8) != short_name.length

    Guild.count(name: /^#{Regexp.quote(name)}/i, _id: {'$ne' => self.id}) do |g|
      @errors << "Guild name '#{self.name}' is already taken." if g > 0

      Guild.count(short_name: /^#{Regexp.quote(short_name)}/i, _id: {'$ne' => self.id}) do |g|
        @errors << "Short name '#{self.short_name}' is already taken." if g > 0

        yield self
      end
    end
  end

  def apply_metadata(metadata)
    # Map metadata
    metadata.keys.each do |k|
      self.send("#{META_MAPPING[k.to_s]}=", metadata[k]) if META_MAPPING[k.to_s]
    end

    (self.members || []).each do |m|
      if player = Game.find_player(m)
        Guild.send_client_changes player
      end
    end

    self
  end

  def construct_metadata
    meta = {}

    META_MAPPING.each_pair do |k,v|
      meta[k] = self.send(v) if self.send(v).present?
    end

    meta['g'] = self.id.to_s
    meta
  end

  def complete?
    [:name, :short_name, :color1, :color2, :color3, :color4, :sign_color, :sign].detect{|k| self.send(k).blank?} == nil
  end

  def member?(player_id)
    members.include? player_id
  end

  def leader?(player_id)
    leader_id == player_id
  end

  def set_leader(player)
    # Capture the previous leader
    prev_leader = self.leader_id

    self.update({'$set' => { leader_id: player.id }, '$addToSet' => { members: player.id }}, false) do
      Guild.set_guild(player, self) do
        if zone = Game.zones[zone_id]
          zone.update_block_owner(position.x, position.y, FRONT, player)
        end

        if prev_leader
          self.alert_player prev_leader, "#{player.name} is now the leader of the \"#{self.name}\" guild."
          self.alert_player player.id, "You are now the leader of the \"#{self.name}\" guild."
        end

        yield if block_given?
      end
    end
  end

  def offer_membership(player)
    sections = [{title: "Guild Membership", text: "You have been invited to join the \"#{self.name}\" guild. Would you like to join?"}]
    player.show_dialog({ 'sections' => sections, 'actions' => 'yesno' }, true, { type: :gadd, guild: self })
  end

  def offer_leadership(player)
    sections = [{title: "Guild Leadership", text: "You have been invited to LEAD the \"#{self.name}\" guild. Do you accept?"}]
    player.show_dialog({ 'sections' => sections, 'actions' => 'yesno' }, true, { type: :gleader, guild: self })
  end

  def add_member(player)
    # Add the player to members and add guild
    self.update({'$addToSet' => { members: player.id }}, false) do
      Guild.set_guild(player, self) do
        self.alert_player leader_id, "#{player.name} is now a member of the \"#{self.name}\" guild."
        self.alert_player player.id, "You are now a member of the \"#{self.name}\" guild."

        yield if block_given?
      end
    end
  end

  def remove_member(player, alert_leader = false)
    # Remove the player from guild members
    self.update({'$pull' => { members: player.id }}, false) do
      # Remove the guild from an ingame player
      Guild.set_guild(player, nil) do
        alert_player player.id, "You are no longer a member of the \"#{self.name}\" guild."
        alert_player self.leader_id, "#{player.name} has been removed from the \"#{self.name}\" guild." if alert_leader

        yield if block_given?
      end
    end
  end

  def decline_membership(player)
    self.alert_player self.leader_id, "#{player.name} has declined to lead the \"#{self.name}\" guild."
  end

  def decline_leadership(player)
    self.alert_player self.leader_id, "#{player.name} has declined to lead the \"#{self.name}\" guild."
  end

  # Set the players guild in the db and ingame (if logged in)
  def self.set_guild(player, guild)
    player.update({guild_id: guild.nil? ? nil : guild.id}) do
      if ingame_player = Game.find_player(player.id)
        ingame_player.guild = guild
        self.send_client_changes ingame_player
      end

      yield if block_given?
    end
  end

  def self.send_client_changes(player)
    short_name = player.guild ? player.guild.try(:short_name) || '' : ''
    player.zone.queue_message EntityChangeMessage.new(player.entity_id, { 'gn' => short_name })
  end

  def clear_location
    self.set_location(nil, nil, nil) do
      yield self if block_given?
    end
  end

  def set_location(zone_id, x, y)
    self.update({zone_id: zone_id, position: [x, y]}) do
      yield self if block_given?
    end
  end

  def near_obelisk(player)
    player.zone_id == self.zone_id && Math.within_range?(player.position, self.position, OBELISK_RANGE)
  end

  def alert_player(player_id, msg)
    if player_id && player = Game.find_player(player_id)
      player.alert(msg) if player
    end
  end
end