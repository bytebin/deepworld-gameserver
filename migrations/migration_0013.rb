# Persist landmarks with >= 5 votes
module Migration0013
  def self.migrate(zone)
    zone.meta_blocks.values.each do |meta_block|
      if meta_block.item.use.landmark
        if meta_block['vc'] && meta_block['vc'] >= Items::Landmark.persistence_vote_threshold
          Items::Landmark.new(nil, zone: zone, meta: meta_block, item: meta_block.item).persist!
        end
      end
    end
  end
end