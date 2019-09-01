# Console command: display guild info
class GuildInfoCommand < BaseCommand
  include GuildCommandHelpers

  def execute
    # Reload the guild in case members have changed
    player.fetch_guild do |g|
      validate_guild_member
      if @errors.present?
        fail
      else
        Zone.find_by_id(g.zone_id, callbacks: false, fields: [:name]) do |zone|

          Player.get(player.guild.members, [:name]) do |members|
            if members.present?
              leader = members.detect{|m| m.id == player.guild.leader_id}.try(:name)
              mems = (members.map{|m| m.name}.sort - [leader]).join(', ')
            end

            leader ||= ' '
            mems = 'none yet!' if mems.blank?

            zone_name = zone ? zone.name : 'None'
            guild_name = 'Unnamed'

            if player.guild.name && player.guild.short_name
              guild_name = "#{player.guild.name} [#{player.guild.short_name}]"
            end

            notify({sections: [
              { 'title' => guild_name },
              { 'text-color' => '4d5b82', 'text' => "Leader: #{leader}" },
              { 'text-color' => '4d5b82', 'text' => "Home World: #{zone_name}" },
              { 'text' => ' ' },
              { 'text-color' => '4d5b82', 'text' => "Members" },
              { 'text' => mems },
            ]}, 1)
          end

        end
      end
    end
  end

  def fail
    alert @errors.join(', ')
  end
end
