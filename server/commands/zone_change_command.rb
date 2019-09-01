class ZoneChangeCommand < BaseCommand
  # TODO: Lock down so that players are near zone teleporter (unless admin)

  data_fields :id

  def execute
    if zone_id = (BSON::ObjectId(id) rescue nil)
      # Prohibit changing to current zone
      if zone_id == zone.id
        alert "You are already in that zone"
      else
        Zone.find_one({ _id: zone_id }, { callbacks: false }) do |change_zone|
          if change_zone
            player.send_to change_zone.id
          else
            alert "Can't find zone #{id} by ID"
          end
        end
      end
    else
      Zone.find_one({ name: id }, { callbacks: false }) do |change_zone|
        if change_zone
          player.send_to change_zone.id
        else
          alert "Can't find zone #{id} by name"
        end
      end
    end
  end

  def validate
    unless active_admin?
      @errors << "You cannot teleport out of Hell." if player.zone.name == 'Hell'
      @errors << "You must complete the tutorial before teleporting to another world." if player.zone.tutorial?
    end
  end

  def fail
    alert @errors.first
  end

end