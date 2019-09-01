class CraftCommand < BaseCommand
  data_fields :item_id
  optional_fields :quantity

  def execute
    send_message = @craft_quantity > 1 || @item.crafting_helpers

    # Subtract inventory of ingredient items
    @ingredients.each do |ingredient|
      player.inv.add Game.item(ingredient.first).code, -ingredient.last * @craft_quantity
    end

    # Item multiplier
    item_multiplier = base_item_multiplier = @item['crafting quantity'] || 1

    # Increase multiplier if near an active crafting enhancement item
    enhancer_item = player.crafting_bonus_for_item?(@item)
    if enhancer_item
      item_multiplier *= 2
      send_message = true
    end

    # Add inventory of crafted item
    player.inv.add @item_id, item_multiplier * @craft_quantity

    zone.items_crafted += @craft_quantity
    player.crafted_item @item, @craft_quantity

    # Send messages
    player.inv.send_message [@item.code] + @ingredients.map{ |i| Game.item(i.first).code } if send_message
    player.notify "#{enhancer_item.title} bonus!", 4 if enhancer_item
  end

  def validate
    get_and_validate_item!
    @craft_quantity = quantity || 1

    if @errors.blank?
      # Verify player's skill level
      if skill_req = @item['crafting skill']
        @errors << "Not skilled enough to craft this item" unless player.adjusted_skill(skill_req[0]) >= skill_req[1]
      end

      if @item.ingredients
        # Quantify single ingredients (e.g. 'brass' instead of ['brass', 2])
        @ingredients = @item.ingredients.map do |ingredient|
          ingredient_name = ingredient.is_a?(Array) ? ingredient.first : ingredient
          ingredient_quantity = ingredient.is_a?(Array) ? ingredient.last : 1
          ingredient_def = Game.item(ingredient_name)
          @errors << "Ingredient #{ingredient} not defined" and break unless ingredient_def
          [ingredient_def.code, ingredient_quantity]
        end

        # Validate player has required amounts of ingredients
        @errors << "Must have required ingredients" unless @ingredients && @ingredients.all? do |ingredient|
          player.inv.quantity(ingredient.first) >= ingredient.last * @craft_quantity
        end
      else
        @errors << "No recipe found for #{@item.id}"
      end

      # Verify crafting helpers
      if @item.crafting_helpers
        # Verify enough helpers are in range
        helpers_in_range = zone.meta_blocks_in_range(player.position, 10, :crafting_helpers)
        @item.crafting_helpers.each do |helper|
          helper_item = Game.item(helper[0])
          if helpers_in_range.count{ |h| h.item.id == helper[0] && (!h.item.steam || zone.peek(h.position.x, h.position.y, FRONT)[1] == 1)} < helper[1]
            count = %w{A Two Three Four Five Six Seven Eight Nine}[helper[1] - 1] || helper[1]
            @errors << "#{count}#{' activated' if helper_item.steam} #{helper_item.name.pluralize(helper[1])} must be in range to craft this item."
            return
          end
        end

        # Verify that helpers aren't overlapping
        all_blocks = helpers_in_range.inject([]) do |memo, h|
          h.item.block_size[0].times.each do |x|
            h.item.block_size[1].times.each do |y|
              memo << [h.position.x + x, h.position.y - y]
            end
          end
          memo
        end
        if all_blocks.size != all_blocks.uniq.size
          @errors << "Crafting machines must not overlap in order to function properly."
        end
      end
    end
  end

  def fail
    alert @errors.first

    # Reset inventory counts
    player.inv.send_message @ingredients.map(&:first) + [@item.code]
  end
end
