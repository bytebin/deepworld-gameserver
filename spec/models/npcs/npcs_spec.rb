require 'spec_helper'
include EntityHelpers

describe 'NPCs' do

  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]

    @ents = Hashie::Mash.new(YAML.load_file('spec/data/npcs.yaml'))
    Game.stub(:entity) do |ent|
      @ents[ent]
    end
  end

  describe 'configuration' do

    before(:each) do
    end

    it 'should assemble an NPC configuration from multiple parts' do
      components = ['automata/tiny', { 'body' => 'automata/golem-tiny-brass', 'vehicle' => 'automata/golem-propeller', 'weapon' => 'automata/golem-tiny-gun' }]
      @entity = Npcs::Npc.new(components, @zone, Vector2.new(0, 0))

      config = @entity.config
      config.code.should == 30
      config.damage.should == ['slashing', 0.333] # Overridden
      config.defense.fire.should == 0.9 # Stays the same
      config.defense.cold.should == 0.2 # Overridden
      config.weakness.energy.should == 0 # Overridden
      config.health.should == 0.75
      config.behavior.map{|h|h.to_hash}.should == [
        { 'type' => 'crawler' },
        { 'type' => 'spawn_attack', 'entity' => 'bullets/steam', 'range' => 4, 'speed' => 9, 'burst' => 5, 'frequency' => 0.33 }
      ]
      config.sprites.should == [['body', 'automata/golem-tiny-brass'], ['vehicle', 'automata/golem-propeller-1'], ['weapon', 'automata/golem-tiny-gun']]
      config.animations.map{|h|h.to_hash}.should == [
        { 'name' => 'idle' },
        { 'name' => 'move', 'sprites' => { 'vehicle' => ['automata/golem-propeller-1', 'automata/golem-propeller-2'] } }
      ]
    end

    it 'should prohibit unlisted NPC parts from being combined' do
      components = ['automata/tiny', { 'body' => 'automata/golem-tiny-brass', 'vehicle' => 'automata/golem-propeller', 'weapon' => 'automata/golem-sawblade' }]
      lambda {
        @entity = Npcs::Npc.new(@zone, @base_entity.code, components, Vector2.new(0, 0))
      }.should raise_error
    end

  end

end