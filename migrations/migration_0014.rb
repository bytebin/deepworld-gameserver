# Add meta blocks for steam-powered items
module Migration0014
  def self.migrate(zone)
    [853, 999, 863, 850, 852].each do |item_code|
      blocks = zone.find_items(item_code)
      blocks.each do |block|
        if zone.get_meta_block(block[0], block[1])
          # Skip
        else
          zone.update_block nil, block[0], block[1], FRONT, item_code
        end
      end
    end
  end
end
