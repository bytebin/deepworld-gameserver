require 'spec_helper'

describe Player do
  describe 'With a zone and player' do
    before(:each) do
      @zone = ZoneFoundry.create
      @one, @o_sock = auth_context(@zone)
      @zone = Game.zones[@zone.id]
    end

    xit 'should not explode when saving a player and zone has been freed' do
      @zone.free!
      Proc.new { @one.save! }.should_not raise_error
    end

    it 'should give me default inventory when I sign up' do
      @one.inv.items.should == {}
    end

    it 'should persist players inventory on an interval' do
      extend_player_reach @one

      # Get a block and mine it so the player has it in inventory
      @item_id = @zone.peek(1,2,FRONT)[0]
      @initial_count = @one.inv.quantity(@item_id)
      Message.new(:block_mine, [1, 2, 2, @item_id, 0]).send(@o_sock)

      Game.persist_players!

      eventually { @one.inv.quantity(@item_id).should eq @initial_count + 1 }
    end

    it 'should respawn me if im buried' do
      @one.position = Vector2[2,2]
      disconnect @o_sock

      # Place some dirt on him
      @zone.update_block nil, 2, 2, FRONT, 512

      @one, @o_sock = login(@zone, @one.id)
      @one.position.should eq @one.spawn_point
    end

    it 'should fix my out of bounds position' do
      @one.position = Vector2[2,-1]
      disconnect @o_sock

      @one, @o_sock = login(@zone, @one.id)

      @one.position.x.should > 0
      @one.position.y.should > 0
    end

    it 'should persist my health between connections' do
      @one.health = 3.0
      disconnect @o_sock

      @one = auth_context(@zone, id: @one.id)[0]
      @one.health.should eq 3.0
    end

    it 'should save my player when I leave' do
      disconnect @o_sock
      player_name = nil

      Player.find_by_id(@one.id, callbacks: false) do |doc|
        doc.should_not be_nil
        player_name = doc.name
      end

      eventually { player_name.should == @one.name }
    end

    it 'should persist my position between connections' do
      @one.position = Vector2.new(3,3)
      @zone.update_block nil, 3, 3, FRONT, 0
      @zone.update_block nil, 3, 2, FRONT, 0

      disconnect @o_sock

      @one = auth_context(@zone, id: @one.id)[0]
      @one.position.to_ary.should eq [3,3]
    end

    it 'should persist my position on zone shutdown' do
      @one.position = Vector2.new(3,3)
      shutdown_zone(@zone)
      reactor_wait

      load_zone(@zone.id)
      @zone.update_block nil, 3, 3, FRONT, 0
      @zone.update_block nil, 3, 2, FRONT, 0

      # Reget player
      @one = login(@zone, @one.id)[0]
      @one.position.to_ary.should eq [3,3]
    end

    it 'should persist my appearance between connections' do
      @one.randomize_appearance!
      @one.fix_appearance
      appearance = @one.appearance
      disconnect @o_sock

      @one = auth_context(@zone, id: @one.id)[0]
      @one.appearance.should == appearance
    end

    it 'should notify my peers of my death' do
      @two, @t_sock = auth_context(@zone)
      Message.new(:health, [0, 0]).send(@o_sock)

      message = Message.receive_one(@t_sock, only: [:entity_status])
      message[:status].should eq [2]
    end

    it 'should reset my position to my spawn point when I respawn' do
      Message.new(:respawn, [0]).send(@o_sock)

      message = Message.receive_one(@o_sock, only: [:player_position])
      message[:x].should eq @one.spawn_point.x
      message[:y].should eq @one.spawn_point.y
    end

    it 'should reset my health when I respawn' do
      Message.new(:respawn, [0]).send(@o_sock)

      message = Message.receive_one(@o_sock, only: [:health])
      message[:amount].should eq 5.0
    end

    it 'should notify my peers of my revival when I respawn' do
      @two, @t_sock = auth_context(@zone)
      Message.new(:respawn, [0]).send(@o_sock)

      message = Message.receive_one(@t_sock, only: [:entity_status])
      message[:status].should eq [3]
    end

    it 'should have my accessory items' do
      @one.inv.remove Game.item_code('accessories/jetpack').to_s
      @one.inv.add Game.item_code('accessories/jetpack-brass')
      @one.inv.move(Game.item_code('accessories/jetpack-brass'), 'a', 0)

      @one.inv.accessories.should eq [Game.item('accessories/jetpack-brass')]
    end

    it 'should add a player\'s suit appearance to their details' do
      @one.inv.remove Game.item_code('accessories/jetpack')

      @one.inv.add Game.item_code('accessories/jetpack-brass')
      @one.inv.move(Game.item_code('accessories/jetpack-brass'), 'a', 0)
      @one.details['u'].should eq Game.item_code('accessories/jetpack-brass')
    end

    describe 'ads' do

      it 'should show ads to free players with > 8 hours of game time' do
        @one.premium = false
        @one.play_time = 10.hours
        @one.show_ads?.should be_true
        @one.config[:show_ads].should be_true
      end

      it 'should not show ads to free players with minimal game time' do
        @one.premium = false
        @one.play_time = 1.hours
        @one.show_ads?.should be_false
        @one.config[:show_ads].should be_false
      end

      it 'should not show ads to premium players' do
        @one.premium = true
        @one.play_time = 10.hours
        @one.show_ads?.should be_false
        @one.config[:show_ads].should be_false
      end

    end

    describe 'health' do

      before(:each) do
        @one.stub(:regen_amount).and_return(0.5)
        @one.stub(:regen_base_interval).and_return(60)
      end

      it 'should regen health on an interval' do
        @one.regen! true
        @one.health = 1

        time_travel 30.seconds
        @one.regen!
        @one.health.should eq 1

        time_travel 30.seconds
        @one.regen!
        @one.health.should eq 1.5
      end

      it 'should regen health faster with a regen accessory' do
        regen_item = stub_item('regen', { 'inventory type' => 'hidden', 'use' => { 'skill bonus' => true }, 'bonus' => { 'regen' => 0.5 } })
        @one.inv.add regen_item.code

        @one.inv.accessories.should include(regen_item)

        @one.regen! true
        @one.health = 1

        time_travel 25.seconds
        @one.regen!
        @one.health.should eq 1

        time_travel 5.seconds
        @one.regen!
        @one.health.should eq 1.5
      end

    end

    describe 'inventory' do

      it 'should replace superceded inventory' do
        item1 = stub_item('item1')
        item2 = stub_item('item2')
        item3 = stub_item('item3')
        superceding_item = stub_item('superceder', { 'supercede_inventory' => ['item1', 'item2'] })

        [item1, item2, item3].each{ |i| @one.inv.add i.code }
        @one.inv.add superceding_item.code

        @one.inv.quantity(item1.code).should eq 0
        @one.inv.quantity(item2.code).should eq 0
        @one.inv.quantity(item3.code).should eq 1
        @one.inv.quantity(superceding_item.code).should eq 1
      end

      it 'should place hidden items in hidden spots in inventory' do
        item = stub_item('item', { 'inventory type' => 'hidden' })
        @one.inv.add item.code, 2

        @one.inv.location_of(item.code).should eq ['z', 9]
      end
    end
  end

  context 'With a zone and 3 hidden players' do
    before(:each) do
      with_a_zone

      with_3_players(@zone, settings: {visibility: 2})
    end

    pending 'should send me followers/followees when i login' do
      # Make some friends and leave
      @two.follow(@three)
      @three.follow(@one)

      disconnect @three.socket

      # Reconnect
      @three, @three.socket = login(@zone, @three.id)

      msgs = Message.receive_many(@three.socket, only: :follow)

      # Followees
      msgs.first.data.should == [[@one.name, @one.id.to_s, 0, true]]

      # Followers
      msgs.last.data.should == [[@two.name, @two.id.to_s, 1, true]]

      bleh = 2
    end
  end

  context 'With a tutorial zone' do
    before(:each) do
      with_a_zone(static: true, static_type: 'tutorial')
      with_2_players(@zone)
      @two.position = @one.position
    end

    it 'should not send my position to others' do
      command! @one, :move, [@one.position.x * 100 + 5, @one.position.y, 0, 0, 1, 0, 0, 1]
      @zone.send_entity_positions_to_all

      Message.receive_one(@two.socket, only: :entity_position).should be_nil
    end

    it 'should not show hints' do
      config = @one.setup_messages.find{ |m| m.is_a?(ClientConfigurationMessage) }
      config.data[1]['show_hints'].should eq false
    end

  end

  context 'With a Beginner zone' do
    before(:each) do
      with_a_zone(scenario: 'Beginner')
      with_a_player(@zone)
    end

    it 'should not show hints' do
      config = @one.setup_messages.find{ |m| m.is_a?(ClientConfigurationMessage) }
      config.data[1]['show_hints'].should eq false
    end

  end

  it 'should migrate reportings to mutings' do
    with_a_zone
    with_a_player(@zone, reportings: [['a', 'abuse'], ['m', 'mute'], ['g', 'griefing']], reportings_count: 3, reportees: [4,5], reportees_count: 2)

    @one.mutings.should eq ({'a' => true, 'm' => true, 'g' => true})
    @one.reportings.should eq nil
    @one.reportings_count.should eq nil
    @one.reportees.should eq nil
    @one.reportees_count.should eq nil

    player = collection(:players).find.first
    player.slice("reportings", "reportings_count", "reportees", "reportees_count").values.should eq []
    player.slice("mutings").values.should eq [{'a' => true, 'm' => true, 'g' => true}]
  end

  context "With a player" do
    let(:player) { PlayerFoundry.create }

    it "should use the players locale for translations" do
      player.stub(:locale).and_return(:en)
      player.t("test", param: "successful").should eq "English successful Test!"

      player.stub(:locale).and_return(:de)
      player.translate("test", param: "erfolgreich").should eq "Deutsche erfolgreich Test!"
    end
  end
end
