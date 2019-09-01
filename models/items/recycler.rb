module Items
  class Recycler < Base

    def use(params = {})
      recycleds = 0
      recyclings = []

      {
        'rubble/iron' => 'building/iron',
        'rubble/copper' => 'building/copper',
        'rubble/brass' => 'building/brass'
      }.each_pair do |scrap, build_item_name|
        scrap_item = Game.item(scrap)

        scrap_inventory = @player.inv.quantity(scrap_item.code.to_s)
        if scrap_inventory > 0
          build_quantity = scrap_inventory / scrap_per_item
          if build_quantity > 0
            # Remove scrap
            scrap_quantity = build_quantity * scrap_per_item
            @player.inv.remove scrap_item.code, scrap_quantity, true

            # Add built items
            build_item = Game.item(build_item_name)
            @player.inv.add build_item.code, build_quantity, true

            recycleds += scrap_quantity
            recyclings << { item: build_item.code, text: "#{build_item.title} x #{build_quantity}" }
          end
        end
      end

      if recyclings.present?
        @player.notify({ sections: [{ title: "You recycled #{recycleds} scrap into:", list: recyclings }] }, 12)
      else
        @player.alert "You do not have enough scrap to recycle."
      end
    end

    def scrap_per_item
      10.lerp(5, (@player.adjusted_skill('building')-1) / 9.0).to_i
    end

  end
end