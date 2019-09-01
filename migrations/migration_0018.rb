# Add earth accents
module Migration0018
  def self.migrate(zone)
    base_code = Game.item_code('base/earth')
    accent_code = Game.item_code('base/earth-accent')
    sz = 5

    b = Benchmark.measure do
      (0..zone.size.x/sz-1).each do |x|
        (0..zone.size.y/sz-1).each do |y|
          origin = Vector2[x * sz, y * sz]
          point = origin + Vector2[rand(sz), rand(sz)]
          if zone.peek(point[0], point[1], BASE)[0] == base_code
            zone.update_block nil, point[0], point[1], BASE, accent_code
          end
        end
      end
    end
  end
end
