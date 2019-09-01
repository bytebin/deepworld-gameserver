module EntityHelpers
  def add_entity(zone, entity_key, entity_count = 1, position = Vector2.new(0,0))
    entity_config = Game.entity(entity_key)

    entities = entity_count.times.map do
      @entity = Npcs::Npc.new(entity_key, @zone, position)
      @zone.add_entity @entity
    end

    entity_count == 1 ? entities[0] : entities
  end

  def kill_entity(player, entities)
    [entities].flatten.each do |e|
      attack_entity player, e
      e.health = 0.01
      e.process_effects 1.0
    end
  end

  def attack_entity(player, entities, item = nil, extend_range = true)
    item ||= {}

    case item
    when String, Fixnum
      item = Game.item(item)
    when Hash
      unless item['code']
        item = stub_item('weapon', { 'category' => 'tools', 'damage' => ['piercing', 1.0], 'damage_duration' => 1.0, 'damage_range' => 3 }.merge(item))
      end
    end

    add_inventory(player, item.code, 1, 'h')
    player.stub(:attack_range).and_return(9999999) if extend_range
    command player, :inventory_use, [0, item.code, 1, [*entities].map(&:entity_id)]
  end

  def create_entity(options = nil)
    @creature = stub_entity('creature', { 'name' => 'creature', 'health' => 5.0 }.merge(options || {}))
    @entity = add_entity(@zone, 'creature', 1)
    @entity.position = Vector2[4, 4]
    @entity
  end

  def behave_entity(entity, times = 1, interval = 0.125)
    times.times do
      time_travel(interval)
      entity.behave!
    end
  end

  def pvp_kill(attacker, victim)
    victim.damage! victim.health, nil, attacker
    victim.respawn!
  end

end