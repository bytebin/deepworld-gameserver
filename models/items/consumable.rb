module Items
  class Consumable < Base

    def use(params = {})
      # Pre-validation
      case @item.action
      when 'skill'
        if tracked_increases_field = @item.action_track
          tracked_increases = player.send(tracked_increases_field)
          if tracked_increases.size >= Player::SKILLS.size
            alert "You have already increased all of your skills with #{@item.title.downcase}s."
            player.inv.send_message @item.code
            return false
          elsif (Player::SKILLS - tracked_increases).none?{ |sk| player.skill(sk) < 10 }
            alert 'You have maximized all skills available for mastery.'
            player.inv.send_message @item.code
            return false
          end
        else
          return false
        end
      when 'convert'
        if @item.convert.keys.none?{ |i| player.inv.contains?(Game.item_code(i)) }
          alert "You do not have any upgradeable items."
          player.inv.send_message @item.code
          return false
        end
      when 'premium'
        if player.premium?
          alert 'You are already a premium player.'
          player.inv.send_message @item.code
          return false
        end
      when 'unlock world'
        unless player.zone.is_owner?(player)
          alert 'You can only unlock your own worlds.'
          player.inv.send_message @item.code
          return false
        end
        unless player.zone.locked
          alert 'This world is already unlocked.'
          player.inv.send_message @item.code
          return false
        end
      end

      # Remove & track inventory
      remove_inventory unless ['convert', 'skill', 'name change', 'teleport'].include?(@item.action)

      # Perform effect
      case @item.action
      when 'heal'
        player.heal! @item.power, false

      when 'stealth'
        player.remove_timers 'end stealth'

        player.stealth = true
        player.change 'xs' => 1

        power = @item.power
        power += player.adjusted_skill(@item.power_bonus[0]) * @item.power_bonus[1] if @item.power_bonus
        player.add_timer power, 'end stealth'

      when 'skill'
        tracked_increases_field = @item.action_track
        tracked_increases = player.send(tracked_increases_field)
        available_skills = (Player::SKILLS - tracked_increases).select{ |sk| player.skill(sk) < player.max_skill_level }

        dialog = { 'title' => "Which skill would you like to increase?", 'input' => { 'type' => 'text select', 'key' => 'skill', 'options' => available_skills.map(&:capitalize), 'max columns' => 5 }}
        player.show_dialog [dialog], true, cancellation: true do |resp|
          if resp == 'cancel'
            handle_dialog_cancel

          else
            # Only allow skill to be increased if not maxed or already increased
            selected_skill = resp.first.downcase
            if available_skills.include?(selected_skill)
              # Update tracked skills
              tracked_increases << selected_skill
              player.update tracked_increases_field => tracked_increases do
                # Remove inventory
                remove_inventory player.v3?

                # Bump skill
                player.points += 1
                player.upgrade_skill selected_skill

                msg = { 'title' => "#{selected_skill.capitalize} increased!", 'text' => "You now have additional mastery of #{selected_skill}." }
                player.show_dialog [msg], false
              end
            end
          end
        end

      when 'teleport'
        if player.teleport!(params, true, 'teleport')
          remove_inventory
        else
          player.inv.send_message @item.code
        end

      when 'convert'
        @items = @item.convert.keys.map{ |i| Game.item(i) }.select{ |item| player.inv.contains?(item.code) }
        opts = @items.map{ |i| i.title }
        dialog = [{ 'title' => 'Which item would you like to upgrade?', 'input' => { 'type' => 'text index', 'key' => 'i', 'options' => opts, 'max columns' => 3 }}]
        player.show_dialog dialog, true, { delegate: self }

      when 'premium'
        player.convert_premium!

      when 'skill reset'
        pts = 0
        player.skills.each_pair do |k, v|
          if player.skills[k] > 1
            player.skills[k] -= 1
            pts += 1
          end
        end
        player.points += pts

        player.send_skills_message
        player.send_points_message
        player.show_dialog Game.config.dialogs.skill_reset, false

      when 'name change'
        player.request_name_change do |success|
          if success
            remove_inventory
            alert 'Name changed. You will reconnect in a moment.'

            EM.add_timer(1){ player.connection.kick(nil, true) }
          end
        end

      when 'unlock world'
        player.zone.update locked: false do |zone|
          alert 'World unlocked!'
        end
      end

      true
    end

    def handle_dialog(values)
      case @item.action
      when 'convert'
        if convert_from = @items[values[0]]
          if convert_to = Game.item(@item.convert[convert_from.id])
            # Fail gracefully if conversion is invalid
            if !player.inv.contains?(@item.code) || convert_to.code == 0
              alert "Sorry, there was an error with the upgrade."
              handle_dialog_cancel
              return
            end

            remove_inventory true
            player.inv.remove convert_from.code, 1, true
            player.inv.add convert_to.code, 1, true
            alert "#{convert_from.title} upgraded to #{convert_to.title}!"
          end
        end
      end
    end

    def handle_dialog_cancel
      player.inv.send_message @item.code
    end

    def remove_inventory(send_message = false)
      player.inv.remove @item.code, 1, send_message
      player.track_inventory_change :consume, @item.code, -1
    end

  end
end