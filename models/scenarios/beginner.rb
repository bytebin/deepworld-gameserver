module Scenarios
  class Beginner < Base

    def load
      @guide_interval = Deepworld::Env.development? ? 10.seconds : 5.minutes
      @guide_shifts = {}
      @guide_chats = {}
      @guide_payment_item = Game.item('accessories/shillings')
      @guide_payment_amount = 5
    end

    def step(delta_time)
      @zone.players.each do |player|
        if player.role?('guide')
          if t = @guide_shifts[player.id]
            # If shift is over, award payment if necessary and start next shift
            if Time.now > t + @guide_interval
              # Only award if player has chatted during interval
              if @guide_chats[player.id] && Time.now < @guide_chats[player.id] + @guide_interval
                player.inv.add @guide_payment_item.code, @guide_payment_amount, true
                player.alert "You earned #{@guide_payment_amount} #{@guide_payment_item.title.downcase.pluralize}"
              end
              @guide_shifts[player.id] = Time.now
            end
          # Begin first shift
          else
            @guide_shifts[player.id] = Time.now
          end
        end
      end
    end

    def player_event(player, event, data)
      case event
      when :chat
        @guide_chats[player.id] = Time.now
      end
    end

  end
end