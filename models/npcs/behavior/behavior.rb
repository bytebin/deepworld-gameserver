class Rubyhave::Behavior
  def blocked_move?(move)
    x = move.x == 0 ? 0 : move.x > 0 ? 1 : -1
    y = move.y == 0 ? 0 : move.y > 0 ? 1 : -1

    blocked = entity.blocked?(x, y) || (x != 0 && entity.blocked?(x, 0)) || (y != 0 && entity.blocked?(0, y))

    if entity.size.x > 1
      additional_width = entity.size.x - 1
      blocked = blocked || entity.blocked?(x+additional_width, y) || (x != 0 && entity.blocked?(x+additional_width, 0)) || (y != 0 && entity.blocked?(additional_width, y))
    end

    if entity.size.y > 1
      additional_height = entity.size.y - 1
      blocked = blocked || entity.blocked?(x, y-additional_height) || (x != 0 && entity.blocked?(x, -additional_height)) || (y != 0 && entity.blocked?(0, y-additional_height))
    end

    blocked
  end

  def zone
    @zone ||= entity.zone
  end

  def complete_block!(block)
    if blocks = get(:directed_blocks)
      blocks.delete block
    end
  end

end