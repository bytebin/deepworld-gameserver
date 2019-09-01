class FacebookCommand < BaseCommand
  data_fields :action, :data

  def execute
    case action
    when 'authenticate'
      player.facebook_connect data, false
    when 'connect'
      player.facebook_connect data, true
    when 'invite'
      player.facebook_invite data
    when 'permissions'
      player.facebook_permissions_changed data
    end
  end

end
