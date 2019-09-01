require 'spec_helper'
include EntityHelpers

describe 'entity attacks' do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twentyempty)
    @one, @o_sock = auth_context(@zone)
    @o_sock.should_not be_blank
    @one.socket.should_not be_blank
    @zone = Game.zones[@zone.id]
  end

  it 'should know how it is being attacked' do
    @entity = add_entity(@zone, stub_entity.name, 1)
    attack_entity @one, @entity
    @entity.active_attack_types.should eq ['piercing']
  end

  describe 'erupt attacks' do

    before(:each) do
      @one.stub(:tracking_entity?).and_return(true)
    end

    it 'should erupt in the correct direction' do
      bullet = stub_entity('bullet')
      stub_entity('eruptor', { 'behavior' => [{ 'type' => 'eruption_attack', 'entity' => 'bullet' }] }  )

      entity = add_entity(@zone, 'eruptor', 1, Vector2.new(4,4))
      behave_entity(entity, 8)

      message = receive_msg!(@one, :entity_status)
      data = message.data.first

      data[0].should == nil # no id
      data[1].should == bullet.code
      data[3].should == 1
      data[4]['<'].should == entity.entity_id
      data[4]['>'].should == [4, -1]
      data[4]['*'].should be_true
    end

  end

  describe 'spawn attacks' do

    before(:each) do
      @bullet = stub_entity('bullet')
      stub_entity('creature', { 'behavior' => [{ 'type' => 'randomly_target' }, { 'type' => 'spawn_attack', 'entity' => 'bullet', 'frequency' => 1, 'range' => 10 }] }  )

      entity = add_entity(@zone, 'creature', 1)

      # Put entity and player close together and make entity "behave"
      @entity.position = Vector2.new(5, 5)
      @one.position = Vector2.new(7, 5)
      @one.update_tracked_entities
      Message.receive_many(@o_sock, only: :entity_status)
    end

    pending 'should spawn bullets towards players in range' do
      @entity.behave!

      message = receive_msg!(@one, :entity_status)
      data = message.data.first

      data[0].should == nil # no id
      data[1].should == @bullet.code
      data[3].should == 1
      data[4]['<'].should == @entity.entity_id
      data[4]['>'].should == @one.entity_id
      data[4]['*'].should be_true
    end

    it 'should not target stealthed players' do
      @one.stub(:stealthy?).and_return(true)

      @entity.behave!
      receive_msg(@one, :entity_status).should be_blank
    end

  end

  describe 'explosions' do

    it 'should damage entities with explosions' do
      @entity = add_entity(@zone, stub_entity.name, 1)
      @entity.position = Vector2[5, 5]
      @zone.explode Vector2[5, 5], 5, @one, false, 5, ['fire']
      @entity.health.should <= 0
    end

    it 'should not damage defending entities with explosions' do
      @entity = add_entity(@zone, stub_entity('defender', 'defense' => { 'fire' => 1.0 }).name, 1)
      @entity.position = Vector2[5, 5]
      @zone.explode Vector2[5, 5], 5, @one, false, 5, ['fire']
      @entity.health.should eq 1.0
    end

  end

  describe 'weakness / strength' do

    before(:each) do
      @one.position = Vector2[5, 5]
    end

    it 'should determine base defense' do
      create_entity({ 'defense' => { 'cold' => 0.5 }})
      @entity.base_defense('cold').should eq 0.5
      @entity.defense('cold').should eq 0.5
    end

    it 'should determine combined defense' do
      create_entity({ 'defense' => { 'cold' => 0.5 }})
      @entity.add_defense nil, nil, type: 'cold', amount: 0.25, duration: 1.0
      @entity.add_defense nil, nil, type: 'fire', amount: 0.25, duration: 1.0
      @entity.defense('cold').should eq 0.75
      @entity.defense('fire').should eq 0.25
    end

    it 'should attack' do
      attack_entity(@one, create_entity, nil, false).errors.should eq []
      @one.can_attack?(@entity, stub_item('weapon')).should eq true
    end

    it 'should track attackers' do
      attack_entity @one, create_entity, nil, false
      @entity.active_attacks.size.should eq 1
      @entity.active_attackers.should eq [@one]
    end

    it 'should track attack types' do
      attack_entity @one, create_entity, nil, false
      @entity.active_attack_types.should eq ['piercing']
    end

    it 'should do normal damage' do
      attack_entity(@one, create_entity, nil, false).errors.should eq []
      attack = @entity.active_attacks.first
      attack.should_not be_blank
      attack.range.should eq 3
      attack.should be_within_range
      attack.damage(1.0).should eq 1.0
      @entity.process_effects 1.0
      @entity.health.should eq 4.0
    end

    it 'should not do damage if out of range' do
      create_entity
      @entity.position = Vector2[10, 10]
      attack_entity @one, @entity, nil, false
      attack = @entity.active_attacks.first
      attack.should_not be_within_range
      @entity.process_effects 1.0
      @entity.health.should eq 5.0
    end

    it 'should add more damage against weaknesses' do
      create_entity({ 'weakness' => { 'cold' => 0.5 } })
      attack_entity @one, @entity, { 'damage' => ['cold', 1.0] }
      @entity.process_effects 1.0
      @entity.health.should eq 3.5
    end

    it 'should block damage against defenses' do
      create_entity({ 'defense' => { 'cold' => 0.5 } })
      attack_entity @one, @entity, { 'damage' => ['cold', 1.0] }
      @entity.process_effects 1.0
      @entity.health.should eq 4.5
    end
  end

  describe 'range' do

    before(:each) do
      add_inventory(@one, 1024)
      @entity = add_entity(@zone, 'terrapus/adult', 1)
    end

    it 'should add temporary defenses' do
      create_entity
      @entity.add_defense nil, nil, type: 'energy', amount: 0.5, duration: 1.second
      @entity.defense('energy').should eq 0.5
    end

    it 'should expire temporary defenses' do
      create_entity
      @entity.add_defense nil, nil, type: 'energy', amount: 0.5, duration: 1.second
      @entity.active_defenses.first.duration.should eq 1.second
      time_travel 0.9.seconds
      @entity.process_effects
      @entity.defense('energy').should eq 0.5
      time_travel 0.11.seconds
      @entity.active_defenses.first.should_not be_active
      @entity.process_effects
      @entity.active_defenses.should be_blank
      @entity.defense('energy').should eq 0
    end

    it 'should combine defenses' do
      create_entity({ 'defense' => { 'cold' => 0.25 } })
      @entity.add_defense nil, nil, type: 'cold', amount: 0.25
      @entity.add_defense nil, nil, type: 'cold', amount: 0.25
      @entity.defense('cold').should eq 0.75
    end

    it 'should replace a source\'s attacks in the same slot' do
      create_entity
      attack_entity(@one, @entity).errors.should eq []
      attack_entity(@one, @entity).errors.should eq []
      @entity.active_attacks.size.should eq 1
    end

    it 'should cancel a source\'s attacks' do
      create_entity
      attack_entity @one, @entity
      @entity.cancel_attack @one, 0
      @entity.active_attacks.size.should eq 0
    end

  end

end