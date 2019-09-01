# Wardrobe update for a player
class WardrobeMessage < BaseMessage
  data_fields :wardrobe_ids

  def data_log
    nil
  end
end
