require 'spec_helper'
include EntityHelpers

describe :switching, :with_a_zone_and_player do

  def setup_switch(switch)
    switched = stub_item('switched', { 'use' => { 'switched' => true } })
    @zone.update_block nil, 5, 5, FRONT, switch.code
    @zone.update_block nil, 10, 10, FRONT, switched.code
    @meta = @zone.set_meta_block(5, 5, switch.code, nil, { '>' => [[10, 10]] })
  end

  def switch!(switch, player = nil)
    Items::Switch.new(player, zone: @zone, position: Vector2[5, 5], item: switch, mod: 0).use!
  end

  describe :switches do

    it 'should change a mod value' do
      switch = stub_item('switch', { 'meta' => 'hidden', 'use' => { 'switch' => true }})
      setup_switch switch

      switch! switch
      @zone.peek(10, 10, FRONT)[1].should eq 1
    end

  end

  describe :timed_switches do

    it 'should return a mod value after a delay' do
      switch = stub_item('switch', { 'meta' => 'hidden', 'use' => { 'switch' => true }})
      setup_switch switch
      @meta['t'] = 3

      switch! switch

      time_travel 2.seconds
      @zone.process_block_timers
      @zone.peek(10, 10, FRONT)[1].should eq 1

      time_travel 2.seconds
      @zone.process_block_timers
      @zone.peek(10, 10, FRONT)[1].should eq 0
    end

  end

  describe :triggers do

    before(:each) do
      touchplate = stub_item('touchplate', { 'meta' => 'hidden', 'use' => { 'switch' => true, 'trigger' => true }})
      setup_switch touchplate
      @zone.peek(10, 10, FRONT)[1].should eq 0
    end

    it 'should trigger touchplates when players moves over them' do
      @one.position = Vector2[5, 5]
      @zone.peek(10, 10, FRONT)[1].should eq 1
    end

    it 'should trigger touchplates even if players skip over them' do
      @one.move! Vector2[4, 5]
      @one.position = Vector2[6, 5]
      @zone.peek(10, 10, FRONT)[1].should eq 1
    end

    it 'should trigger touchplates when entities move over them' do
      @entity = add_entity(@zone, stub_entity.name, 1)
      @entity.position = Vector2[5, 5]
      @zone.peek(10, 10, FRONT)[1].should eq 1
    end

  end

  describe :messages do

    def set_switch_message(msg)
      @switch_meta = @zone.set_meta_block(5, 5, @switch.code, nil, { '>' => [[10, 10]], 'm' => msg })
    end

    before(:each) do
      @switch = stub_item('switch', { 'meta' => 'hidden', 'use' => { 'switch' => true }})
      @sign = stub_item('sign', { 'meta' => 'hidden', 'use' => { 'switched' => 'MessageSign' } })

      @zone.update_block nil, 5, 5, FRONT, @switch.code
      @zone.update_block nil, 10, 10, FRONT, @sign.code

      @one.stub(:active_in_chunk?).and_return(true)
    end

    it 'should emote a message' do
      set_switch_message 'hey there'
      switch! @switch, @one
      receive_msg!(@one, :effect).data.should eq [550.0, 500.0, 'emote', 'hey there']
    end

    it 'should emote an interpolated message' do
      @one.name = 'jimmy'
      set_switch_message '*player* is a doofus'
      switch! @switch, @one
      receive_msg!(@one, :effect).data.should eq [550.0, 500.0, 'emote',  'jimmy is a doofus']
    end

    it 'should set a message on a mechanical sign' do
      @one.name = 'jimmy'
      set_switch_message '*player* is a doofus'
      switch! @switch, @one
      @zone.get_meta_block(10, 10)['t1'].should eq 'jimmy is a doofus'
    end


  end

  describe :relays do

    before(:each) do
      @switch = stub_item('switch', { 'meta' => 'hidden', 'use' => { 'switch' => true }})
      relay = stub_item('relay', { 'meta' => 'hidden', 'use' => { 'switch' => true, 'switched' => 'Relay', 'multi' => true } })
      switched = stub_item('switched', { 'use' => { 'switched' => true } })

      @zone.update_block nil, 5, 5, FRONT, @switch.code
      @zone.update_block nil, 10, 10, FRONT, relay.code
      @zone.update_block nil, 15, 15, FRONT, switched.code
      @zone.update_block nil, 15, 16, FRONT, switched.code
      @zone.update_block nil, 15, 17, FRONT, switched.code
      @switch_meta = @zone.set_meta_block(5, 5, @switch.code, nil, { '>' => [[10, 10]] })
      @relay_meta = @zone.set_meta_block(10, 10, relay.code, nil, { '>' => [[15, 15], [15, 16], [15, 17]] })
    end

    it 'should switch switchables in sequence' do
      switch! @switch
      @zone.peek(15, 15, FRONT)[1].should eq 1
      @zone.peek(15, 16, FRONT)[1].should eq 0
      @zone.peek(15, 17, FRONT)[1].should eq 0

      switch! @switch
      @zone.peek(15, 15, FRONT)[1].should eq 1
      @zone.peek(15, 16, FRONT)[1].should eq 1
      @zone.peek(15, 17, FRONT)[1].should eq 0

      switch! @switch
      @zone.peek(15, 15, FRONT)[1].should eq 1
      @zone.peek(15, 16, FRONT)[1].should eq 1
      @zone.peek(15, 17, FRONT)[1].should eq 1

      switch! @switch
      @zone.peek(15, 15, FRONT)[1].should eq 0
      @zone.peek(15, 16, FRONT)[1].should eq 1
      @zone.peek(15, 17, FRONT)[1].should eq 1
    end

    it 'should reset a sequence' do
      @relay_meta['r'] = 3

      switch! @switch
      @zone.peek(15, 15, FRONT)[1].should eq 1
      @zone.peek(15, 16, FRONT)[1].should eq 0
      @zone.peek(15, 17, FRONT)[1].should eq 0

      time_travel 4.seconds

      switch! @switch
      @zone.peek(15, 15, FRONT)[1].should eq 0
      @zone.peek(15, 16, FRONT)[1].should eq 0
      @zone.peek(15, 17, FRONT)[1].should eq 0
    end

    pending 'should randomly switch between switchables' do
      @meta['y'] = 'Random'
      switch! @switch
    end

  end

end
