class Text
  def self.distance_of_time(seconds)
    if seconds == 0
      desc = "now"
    elsif seconds == 1
      desc = "in 1 second"
    elsif seconds <= 60
      desc = "in #{seconds} seconds"
    else
      desc = "in #{seconds.to_period}"
    end
  end
end
