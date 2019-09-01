class SummonCommand < BaseCommand
  data_fields :summonee_name

  def execute
    @summonee.move! player.position
    player.update last_summoned_at: Time.now
  end

  def validate
    @errors << "No mass teleportation machine is operational in this world." unless zone.machine_exists?(player, 'teleport')
    @errors << "Insufficient priveleges." unless zone.machine_allows?(player, 'teleport', 'summon')
    @errors << "You can only summon once per minute." if player.last_summoned_at && Time.now < player.last_summoned_at + 1.minute && !player.admin?

    @summonee = zone.find_player(summonee_name)
    @errors << "Couldn't find player '#{summonee_name}'" unless @summonee
    @errors << "Cannot summon an admin." if @summonee.try(:admin?)
  end

end
