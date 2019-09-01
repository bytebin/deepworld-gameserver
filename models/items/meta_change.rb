module Items
  class MetaChange < Base

    def use(params = {})
      if change = @item.use.meta_change
        item_code = Game.item_code(change.block)
        if block = @zone.meta_blocks_with_item(item_code).first
          if append = @item.use.meta_change.append
            key = append[0]
            val = append[1] == 'item' ? @item.code : append[1]
            block[key] ||= []
            block[key] << val
          end
        end
      end
    end
  end
end