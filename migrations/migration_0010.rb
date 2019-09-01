module Migration0010
  def self.migrate(zone)
    skeleton_keys = zone.find_items(1073)

    skeleton_keys.each do |s|
      zone.update_block(nil, s[0], s[1], FRONT, 970, 0)
    end
  end
end