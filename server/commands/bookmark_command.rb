class BookmarkCommand < BaseCommand
  data_fields :type, :id, :active

  def execute
    case type
    when 'zone'
      if active
        player.update({'$addToSet' => { 'bookmarked_zones' => BSON::ObjectId(id) }}, false)
      else
        player.update({'$pull' => { 'bookmarked_zones' => BSON::ObjectId(id) }}, false)
      end
    end
  end

  def validate
    @errors << "Invalid active type" unless active.is_a?(TrueClass) || active.is_a?(FalseClass)
    error_and_notify "Invalid #{type}" unless id.is_a?(String) && id.size == 24
  end

end