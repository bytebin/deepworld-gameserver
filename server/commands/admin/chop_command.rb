class ChopCommand < BaseCommand
  admin_required
  data_fields :from_x, :from_y, :to_x, :to_y

  def execute
    serializer = ZoneChopSerializer.new(zone, Vector2[from_x, from_y], Vector2[to_x, to_y])

    # Make sure we have enough data for the chunks
    if serializer.destination.x > zone.size.x || serializer.destination.y > zone.size.y
      @errors << "Need even number of chunks. Try and reduce the destination a little."
      failure! && return
    end

    zone.pause
    zone.persist! serializer

    # Update the size on the document
    zone.update(size: serializer.size.to_a) do
      zone.shutdown!(false) # Shutdown but don't re-persist
    end
  end

  def validate
    #@errors << "Cannot chop an 'active' zone, deactivate first" if zone.active
    validate_fields
    @errors << "Too many players in the zone. 'There can be only one!'" if zone.players_count > 1

    @errors << "from_x is out of bounds" if from_x < 0
    @errors << "from_y is out of bounds" if from_y < 0
    @errors << "to_x is out of bounds" if to_x > zone.size.x
    @errors << "to_y is out of bounds" if to_y > zone.size.y
    @errors << "to_x must be greater than from_x" if to_x <= from_x
    @errors << "to_y must be greater than from_y" if to_y <= from_y
  end

  def validate_fields
    self.class.fields.each do |f|
      begin
        self.send("#{f}=", Integer(self.send(f)))
      rescue
        @errors << "Value #{self.send(f)} is invalid for #{f}."
      end
    end
  end

  def fail
    alert @errors.join(', ')
  end
end
