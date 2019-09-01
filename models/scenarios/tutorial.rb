module Scenarios
  class Tutorial < Base

    def player_event(player, event, data)
      case event
      when :entered
        player.queue_message EventMessage.new('hideGuiElement', 'worldButton')
        player.queue_message EventMessage.new('hideGuiElement', 'shopButton')
      end
    end
  end
end