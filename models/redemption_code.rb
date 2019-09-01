class RedemptionCode < MongoModel
  fields [:code, :inventory, :wardrobe, :appearance, :crowns, :limit, :redemptions, :redeemers, :premium]
  fields :created_at, Time

  def redeem!(player)
    apply_inventory(player) if self.inventory
    apply_appearance(player) if self.appearance
    apply_wardrobe(player) if self.wardrobe
    apply_crowns(player) if self.crowns && self.crowns != 0

    # Update the redemption code
    self.update({last_redeemed_at: Time.now, redemptions: (self.redemptions || 0) + 1})
    self.update({'$addToSet' => { redeemers: player.id }}, false)

    # Send player a notification bout dey new stuff!
    player.notify(self.to_notification, 12)

    # Save the player
    player.save!
  end

  def apply_inventory(player)
    self.inventory.each_pair do |item, quantity|
      player.inv.add item, quantity.to_i
      player.track_inventory_change :redeem, item.to_i, quantity.to_i
    end

    player.inv.send_message self.inventory.keys
  end

  def apply_appearance(player)
    self.appearance.each_pair do |appearance_item, value|
      player.appearance[appearance_item] = value
    end

    player.zone.queue_message EntityStatusMessage.new([player.status])
  end

  def apply_wardrobe(player)
    # Only add wardrobe items that the player does not yet have
    (self.wardrobe - player.wardrobe).each do |item|
      player.wardrobe << item
    end

    player.queue_message WardrobeMessage.new(self.wardrobe)
  end

  def apply_crowns(player)
    Transaction.credit(player, self.crowns, 'redemption')
  end

  def available?
    self.redemptions.nil? || self.redemptions < self.limit
  end

  def redeemed_by?(player_id)
    self.redeemers && self.redeemers.include?(player_id)
  end

  def to_notification
    items = []
    items += self.inventory.map { |item, quant| {item: item, text: "#{Game.item(item).title} x #{quant}"} } if self.inventory
    items += self.wardrobe.map { |item| {item: item, text: "#{Game.item(item).title} x 1"} } if self.wardrobe
    items += [{image: 'shop/crowns', text: "Crowns x #{self.crowns}"}] if self.crowns && self.crowns > 0

    { sections: [ {title: 'You received:', list: items } ] }
  end
end