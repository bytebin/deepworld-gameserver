class ChangePasswordCommand < BaseCommand
  data_fields :old_password, :new_password

  def execute
    player.set_password new_password do
      player.alert "Your password has been updated!"
    end
  end

  def validate
    unless player.password_matches?(old_password)
      @errors << "Your old password is invalid - please try again."
    end

    unless new_password.is_a?(String) && (4..20).include?(new_password.size)
      @errors << "Passwords must be between 4 and 20 characters in length."
    end
  end

  def fail
    player.alert @errors.first
  end

end