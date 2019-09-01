module Scenarios
  class TutorialGiftHomeWorld < Base

    def update_player_configuration(player, cfg)
      cfg['shop']['sections'][1]['items'].unshift 'home-world'
    end

    def validate_command(command)
      case command
      when ChatCommand
        #command.error_and_notify 'Chatting is disabled during tutorial.'

      when TransactionCommand
        # Prohibit all purchases but home world purchase in tutorial
        unless command.item.tutorial
          command.errors << "You cannot purchase that item in the tutorial."
        end
      end
    end

    def player_event(player, event, data)
      case event
      when :entered
        player.queue_message EventMessage.new('uiHints', [])
        player.update 'segments.tutorial' => 'TutorialGiftHomeWorld'

      when :waypoint
        if data.first == 'end'
          unless player.hints_in_session.include?(:tutorial_gift_home_world)
            gift_crowns_if_needed player
            auto_purchase_after_delay player, 30

            player.hints_in_session << :tutorial_gift_home_world
            player.show_dialog Game.config.dialogs.tutorial_gift_home_world, true, { cancellation: true } do
              show_purchasing_hints player
            end
          end
        end
      end
    end

    def show_purchasing_hints(player)
      player.queue_message EventMessage.new('uiHints', [
        { 'message' => 'Click and go!', 'highlight' => 200 },
        { 'message' => 'Click on the Home World icon', 'highlight' => 105 },
        { 'message' => 'Click to open the shop', 'highlight' => 100 }
      ])
    end

    def auto_purchase_after_delay(player, delay)
      EM.add_timer(delay) do
        if !player.disconnected
          player.update 'segments.tutorial_flow' => 'auto_purchase' do |pl|
            Transaction.debit player, 'home-world', 190
            TutorialGiftHomeWorld.provision_world! player
          end
        end
      end
    end

    def gift_crowns_if_needed(player)
      unless player.loots.include?(:tutorial_gift_home_world)
        player.loots << :tutorial_gift_home_world
        Transaction.credit player, 200, 'tutorial_gift_home_world'
      end
    end

    def show_in_recent?
      false
    end

    def self.provision_world!(player)
      # Ensure pickaxe and pistol
      player.inv.add Game.item_code('tools/pickaxe') unless player.inv.contains?(Game.item_code('tools/pickaxe'))
      player.inv.add Game.item_code('tools/pistol') unless player.inv.contains?(Game.item_code('tools/pistol'))
      player.inv.move Game.item_code('tools/pickaxe'), 'h', 0
      player.inv.move Game.item_code('tools/pistol'), 'h', 1

      # Provision world
      query_params = { active: false, scenario: 'HomeWorld' }
      update_params = { active: true, owners: [player.id], private: true, locked: true }
      Zone.update(query_params, update_params) do
        Zone.where(owners: [player.id]).first do |zone|
          if zone
            player.update owned_zones: player.owned_zones + [zone.id] do |pl|
              player.send_to zone.id, true
            end
          else
            player.update zone_id: nil do
              player.kick "Teleporting...", true
            end
          end
        end
      end
    end

  end
end
