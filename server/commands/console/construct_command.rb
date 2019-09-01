# Construct prefab at position
class ConstructCommand < BaseCommand
  data_fields :x, :y, :prefab_name
  admin_required

  def execute
    Prefab.where(name: @prefab_name).first do |prefab|
      if prefab.present?
        zone.place_prefab @x, @y, prefab
      else
        alert "Couldn't find prefab '#{@prefab_name}'"
      end
    end
  end

  def validate
    @x = @x.to_i
    @y = @y.to_i
    @errors << "Position must be in bounds" unless zone.in_bounds?(@x, @y)
  end

  def fail
    alert @errors.join(', ')
  end

end
