class RegisterCommand < BaseCommand

  def execute
    if player.registered?
      alert "You are already registered #{player.email ? 'as ' + player.email : ' via Facebook.'}"
      player.unlock_logout!
    else
      player.request_registration true
    end
  end

end
