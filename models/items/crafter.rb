module Items
  class Crafter < Base

    def use(params = {})
      @character_name = params[:character_name]

      unless @item.craft && @item.craft.options.present?
        player.show_dialog dialog("Sorry, that item doesn't have any crafting options.")
        return false
      end

      msg = "I can use your #{@item.title.downcase} to craft something if you have the supplies."
      dialog = dialog(msg) + craft_options + [{ 'text' => 'Never mind.', 'choice' => 'cancel', 'text-color' => Behavior::Dialoguer::CHOICE_COLOR }] + [{ 'text' => ' ' }]

      player.show_dialog dialog do |resp|
        if craft_item = Game.item(resp.first)
          # Get ingredients list
          ingredients = @item.craft.options[resp.first].dup

          # Add in source item as well so it is consumed
          ingredients[@item.id] ||= 1

          # Validate that player has necessary inventory
          error = nil
          ingredients.each do |k, v|
            ingredient = Game.item(k)
            unless player.inv.contains?(ingredient.code, v)
              error = "Oops, you need more #{ingredient.title.downcase} for me to craft that!"
              break
            end
          end

          # Show error and return if necessary
          if error
            player.show_dialog dialog(error), false

          # No errors, so go ahead with crafting
          else
            # Subtract ingredients from inventory
            ingredients.each do |k, v|
              ingredient = Game.item(k)
              player.inv.remove ingredient.code, v, true
            end

            # Add crafted item to inventory
            player.inv.add_with_message craft_item, 1, "All right, here you go!"
          end
        end
      end
    end

    def dialog(msg)
      [{ 'title' => @character_name }, { 'text' => msg }]
    end

    def craft_options
      @item.craft.options.map do |k, v|
        result = Game.item(k)
        ingredient_description = v.map do |ingredient_name, ingredient_count|
          ingredient = Game.item(ingredient_name)
          "#{ingredient.title} x #{ingredient_count}"
        end.join(', ')
        [{ 'text' => result.title, 'choice' => k, 'item' => k, 'text-color' => Behavior::Dialoguer::CHOICE_COLOR }, { 'text' => "Requires: #{ingredient_description}", 'text-scale' => 0.6, 'text-color' => '555555' }]
      end.flatten
    end
  end
end