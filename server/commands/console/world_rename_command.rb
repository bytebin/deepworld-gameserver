# Console command: change the name of a world
class WorldRenameCommand < BaseCommand
  data_fields :name

  include WorldCommandHelpers

  def execute
    Zone.count(name: /^#{name}$/i) do |w|
      err = "World name '#{name}' is already taken." if w > 0

      if err.blank?
        zone.rename!(name) do
          save_command_history!
          zone.reconnect_all!('Renamed world')
        end
      else
        alert err
      end
    end
  end

  def validate
    run_if_valid :validate_owner
    run_if_valid :validate_name
    run_if_valid :validate_command_history, 1.day
  end

  def validate_name
    if name.blank? || name.length < 5 || name.length > 20
      @errors << "World name must be between 5 and 20 characters."
    else
      @name = @name.strip

      if Deepworld::Obscenity.is_obscene?(name)
        @errors << "World name #{name} is inappropriate."
      elsif name.match /[^0-9a-z ]/i
        @errors << "World name can only contain numbers and letters."
      end
    end
  end

  def fail
    alert @errors.join(', ')
  end
end
