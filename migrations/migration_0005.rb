module Migration0005
  def self.migrate(zone)
    # Zero out all ownership information
    zone.kernel.clear_owners

    # Front mods
    # all 180s(20) become 2 for item.mod == 'rotation'
    # all 90s(26) become 1 for item.mod == 'rotation'
    # all 270s(14) become 3 for item.mod == 'rotation'
    (0..(zone.size.x - 1)).each do |x|
      (0..(zone.size.y - 1)).each do |y|
        block = zone.peek(x, y, FRONT)

        mod = nil

        item = Game.item(block[0])

        if item && item.mod == 'rotation'
          case block[1]
          when 26
            mod = 1
          when 20
            mod = 2
          when 14
            mod = 3
          end

          zone.update_block(nil, x, y, FRONT, nil, mod, nil) unless mod.nil?
        elsif item.nil?
          zone.update_block(nil, x, y, FRONT, 0, 0, nil)
        end
      end
    end
  end
end
