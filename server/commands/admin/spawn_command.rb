# Spawn an entity

class SpawnCommand < BaseCommand
  admin_required
  data_fields :entity_type, :x, :y

  def execute
    Dir[File.join(Deepworld::Loader.root, 'models/npcs', '**/*.rb')].each {|f| load f}

    if ent = zone.spawn_entity(entity_type, @x, @y, nil, true)
      ent.behavior.react :anger, nil
      # It worked!
    else
      alert "Couldn't find entity #{entity_type}"
    end
  end
end