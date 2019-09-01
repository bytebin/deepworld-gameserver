class Campaign < MongoModel
  START_DATE = Date.new(2013, 9, 24)

  fields [:ref, :description, :items]

  # Give campaign gift on spawn
  def self.give_items(player)
    if player.ref && player.created_at >= START_DATE && !player.rewards['welcome']
      Campaign.where(ref: player.ref).first do |camp|
        if camp && camp.items
          camp.items.each do |i|
            if item = Game.item(i)
              player.inv.add item.code, 1, true
              player.show_dialog([
                { 'title' => 'Here is your welcome Gift!', 'image' => "consumables/gift" },
                { 'text' => "#{item.title} x 1" } ])
            end
          end

          player.update :'rewards.welcome' => Time.now.to_i

        else
          player.update :'rewards.welcome' => nil
        end
      end
    end
  end
end