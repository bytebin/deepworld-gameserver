class Product < MongoModel
  MAX_ITEMS = 6

  fields [:code, :name, :cost, :summary, :enabled, :premium, :crowns, :discount]

  def self.enabled
    where({enabled: true}).sort(:cost)
  end

  def self.shop_hash(products, player)
    shop = {'currency' => {}}

    if player.free? && products.detect{|p| p.code == 'premium'}
      max_currency_items = MAX_ITEMS - 1
    else
      max_currency_items = MAX_ITEMS
    end

    # Compute discounts
    base_crowns_per_dollar = 100 / 1.99
    crown_products = products.select{ |i| !i.premium }.sort_by{ |i| i.cost }
    crown_products.each do |prod|
      ratio = prod.crowns_per_dollar / base_crowns_per_dollar
      perc = (((ratio - 1.0) * 100) / 5).round * 5
      prod.discount = "#{perc.to_i}% more" if perc >= 5
    end

    # Hashify
    products.sort_by{ |i| (i.premium ? 0 : 100000) + i.cost }.each do |p|
      if player.v2?
        if p.code == 'premium'
          shop['premium'] = p.to_h if player.free?
        else
          shop['currency'][p.code] = p.to_h if (shop['currency'].length < max_currency_items)
        end
      else
        shop['currency'][p.code] = p.to_h
      end
    end

    shop
  end

  def crowns_per_dollar
    1.0 * (self.crowns || 0) / self.cost
  end

  def to_h
    return @hash if @hash

    @hash = {
      'identifier' => self.code,
      'title' => self.name,
      'price' => self.cost.to_s
    }

    if self.code == 'premium'
      @hash['description'] = 'Unlock your potential with a premium account! Get looting perks like crown multipliers and special clothes, explore bonus worlds, and more. This upgrade is a one-time fee and lasts forever.'
    else
      @hash['description'] = "#{self.crowns} crowns (can be used to obtain private worlds, protectors, and more)"
      @hash['quantity'] = self.crowns
      @hash['discount'] = self.discount
    end

    @hash
  end

  def self.for_key(product_key)
    Game.config.products.select{|p| p.code == product_key}
  end
end

# shop:
#   premium:
#     identifier: premium
#     title: Premium Upgrade
#     price: 2.99
#     description: Experience all Deepworld has to offer with a premium account. Explore new environments, hundreds of different premium worlds, and a wide variety of new skills and achievements.
#   currency:
#     crowns_tier_0:
#       identifier: crowns_tier_0
#       title: 100 crowns
#       quantity: 100
#       price: 1.99
#       description: 100 crowns (can be used to obtain private worlds, protectors, and more)
#     crowns_tier_1:
#       identifier: crowns_tier_1
#       title: 250 crowns
#       quantity: 250
#       price: 4.99
#       description: 250 crowns (can be used to obtain private worlds, protectors, and more)
#     crowns_tier_2:
#       identifier: crowns_tier_2
#       title: 550 crowns
#       quantity: 550
#       price: 9.99
#       description: 550 crowns (can be used to obtain private worlds, protectors, and more)
#     crowns_tier_3:
#       identifier: crowns_tier_3
#       title: 1200 crowns
#       quantity: 1200
#       price: 19.99
#       description: 1200 crowns (can be used to obtain private worlds, protectors, and more)
#     crowns_tier_4:
#       identifier: crowns_tier_4
#       title: 1900 crowns
#       quantity: 1900
#       price: 29.99
#       description: 1900 crowns (can be used to obtain private worlds, protectors, and more)
