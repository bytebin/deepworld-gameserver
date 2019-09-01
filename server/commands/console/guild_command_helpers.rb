module GuildCommandHelpers
  def validate_guild_member
    @errors << "Sorry, you are not a member of a guild." unless player.guild
  end

  def validate_guild_owner
    unless player.guild && player.guild.leader?(player.id)
      @errors << "Sorry, you are not a guild leader."
    end
  end

  def validate_names_set
    unless player.guild.name && player.guild.short_name && player.guild.name.length > 0 && player.guild.short_name.length > 0
      @errors << "Please set your guilds name and shortname first."
    end
  end
end
