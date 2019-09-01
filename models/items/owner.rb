# Notifies player of who the owner of a meta block is
module Items
  class Owner < Base

    def use(params = {})
      if @meta && @meta.player?
        Player.get_name(@meta.player_id) do |player_name|
          player_name ||= 'an unknown player'
          alert "This #{@item.title.downcase} is owned by #{player_name}."
        end
      end
    end
  end
end