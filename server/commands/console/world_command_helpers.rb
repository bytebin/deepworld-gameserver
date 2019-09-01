module WorldCommandHelpers
  def validate_owner
    unless admin?
      if zone && !zone.owners.include?(player.id)
        @errors << "Sorry, you do not own this world."
      end
    end
  end

  def validate_unlocked
    unless admin?
      if zone && zone.locked
        @errors << "Sorry, this world is locked. You can unlock it with a World Key."
      end
    end
  end

  def validate_command_history(minimum_interval)
    unless admin?
      if history = zone.command_history[self.class.name.underscore]
        if minimum_interval.to_i > Time.now - Time.at(history[1])
          @errors << "Sorry, you must wait before you can do this again."
        end
      end
    end
  end

  def validate_toggle(toggle)
    unless toggle.present? && ['on','off'].include?(toggle.strip.downcase)
      @errors << "Toggle value of '#{toggle}'' is invalid."
    end
  end

  def parse_toggle(toggle)
    if toggle.strip.downcase == 'on'
      return true
    else
      return false
    end
  end

  def save_command_history!
    if history = zone.command_history[self.class.name.underscore]
      history[0] += 1
      history[1] = Time.now.to_i
    else
      history = [1, Time.now.to_i]
    end

    zone.command_history[self.class.name.underscore] = history
  end
end