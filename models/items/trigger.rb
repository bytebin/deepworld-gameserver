module Items
  class Trigger < Base

    def use(params = {})
      trigger_peek = @zone.peek(@position.x, @position.y, FRONT)
      @item ||= Game.item(trigger_peek[0])
      if @item && @item.use.trigger
        Items::Switch.new(
          nil,
          zone: @zone,
          entity: @entity,
          item: @item,
          position: @position,
          mod: trigger_peek[1]
        ).use!
      end
    end
  end
end