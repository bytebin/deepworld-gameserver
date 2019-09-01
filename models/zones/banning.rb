module Zones
  module Banning

    def ban!(player, duration)
      if !player.admin
        update "bannings.#{player.id.to_s}" => Time.now.to_i + duration do
          if player.connection
            player.alert "You've been banned for #{duration/60} minute(s)."
            EM.add_timer(Deepworld::Env.test? ? 0 : 3.0) do
              player.send_to nil
            end
          end
        end
        true
      else
        false
      end
    end

    def unban!(player)
      update "bannings.#{player.id.to_s}" => nil do
        # Yay
      end
    end

    def banned?(player)
      Time.now.to_i < (bannings[player.id.to_s] || 0)
    end

  end
end

