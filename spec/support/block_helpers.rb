module BlockHelpers
  def place(x, y, item, player = @one)
    command(player, :block_place, [x, y, FRONT, item, 0])
  end

  def mine(x, y, item, player = @one)
    command(player, :block_mine, [x, y, FRONT, item, 0])
  end

  def place!(x, y, item, player = @one)
    command!(player, :block_place, [x, y, FRONT, item, 0])
  end

  def mine!(x, y, item, player = @one)
    command!(player, :block_mine, [x, y, FRONT, item, 0])
  end
end