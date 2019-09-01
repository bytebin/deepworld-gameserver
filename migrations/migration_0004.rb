module Migration0004
  def self.migrate(zone)
    # Activate user-placed inactive teleporters
    zone.meta_blocks.values.each do |meta_block|
      if [Game.item_code('mechanical/teleporter'), Game.item_code('mechanical/zone-teleporter')].include?(meta_block.item.code)
        zone.update_block nil, meta_block.x, meta_block.y, FRONT, meta_block.item.code, 1
      end
    end
  end
end
