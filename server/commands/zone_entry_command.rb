class ZoneEntryCommand < BaseCommand
  data_fields :entry_code

  def execute
    if player.zone.name == 'Hell'
      alert "Sorry, you're not allowed out of Hell."
      return
    end

    Zone.find_one({entry_code: entry_code}, { callbacks: false }) do |change_zone|
      if change_zone.nil?
        alert "Can't find a zone for that code."

      elsif change_zone.id == zone.id
        alert "You are already in #{zone.name}."

      elsif change_zone.can_play? player.id
        alert "You're already a member of #{change_zone.name}.\nFind yourself a teleporter."

      elsif change_zone.locked
        alert "That world is locked."

      elsif [change_zone.owners].flatten.compact.length == 0
        change_zone.add_owner(player) { player.send_to change_zone.id }

      else
        change_zone.add_member(player) { player.send_to change_zone.id }

      end
    end
  end
end