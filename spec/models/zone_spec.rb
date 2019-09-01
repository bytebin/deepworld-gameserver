require 'spec_helper'

describe Zone do

  it 'should shut down cleanly' do
    @zone = ZoneFoundry.create

    auth_context(@zone)
    @zone = Game.zones[@zone.id]
    @zone.server_id.should eq Game.document_id

    @zone.shutdown!

    eventually { collection(:zones).find_one({'_id' => @zone.id})['server_id'].should be_nil }
  end

  describe 'client config', :with_a_zone_and_player do

    before(:each) do
      @one.current_client_version = '3.1.0'
    end

    it 'should send protected status to non-members of protected worlds' do
      @zone.protection_level = 10
      @zone.protected_against?(@one).should be_true
      status = @zone.client_config(@one, true)
      status['protected'].should eq true
      status['protected_reason'].should be_nil
    end

    it 'should not send protected status to members of protected worlds' do
      @zone.protection_level = 10
      @zone.members << @one.id
      @zone.protected_against?(@one).should be_false
      status = @zone.client_config(@one, true)
      status['protected'].should be_nil
      status['protected_reason'].should be_nil
    end

    it 'should send protected status to non-leveled players' do
      @zone.protection_level = 1
      @zone.protected_against?(@one).should be_true
      status = @zone.client_config(@one, true)
      status['protected'].should eq true
      status['protected_reason'].should =~ /high\-level/
    end

    it 'should not send protected status to leveled players' do
      @zone.protection_level = 1
      @one.level = 10
      @one.play_time = 2.days
      @zone.protected_against?(@one).should be_false
      status = @zone.client_config(@one, true)
      status['protected'].should be_nil
      status['protected_reason'].should be_nil
    end

    it 'should not send protected status if it is not protected' do
      @zone.protected_against?(@one).should be_false
      status = @zone.client_config(@one, true)
      status['protected'].should be_nil
      status['protected_reason'].should be_nil
    end

  end

  describe 'with a zone' do
    before(:each) do
      # Create and load up zone with a login
      @zone = ZoneFoundry.create
      @one, @o_sock = auth_context(@zone)
      disconnect(@o_sock)

      @zone = Game.zones[@zone.id]

      # Should be setup correctly
      @zone.server_id.should eq Game.document_id
    end

    it 'should persist' do
      @zone.persist!

      # Verify the newly saved file is the same as the input zone file
      FileUtils.compare_file(@zone.data_path, File.join(Deepworld::Loader.root, 'tmp', @zone.data_path.split('/').last)).should eq true
    end

    it 'should boot everyone and alert if it is duplicatively loaded on two servers' do
      collection(:zones).update({ _id: @zone.id }, { server_id: @zone.id })

      @zone.check!

      eventually do
        @one.connection.disconnected.should be_true
        Game.zones.should be_blank
        Alert.all do |a|
          a.size.should eq 1
          a.first.message.should =~ /duplicat/
        end
      end
    end

    it 'should shut itself down and save the zone to file' do
      @zone.shutdown!
      eventually do
        @zone.reload
        @zone.last_saved_at.should_not be_nil
        @zone.server_id.should be_nil
      end
    end

    it 'should save players on zone shutdown' do
      two, sock = auth_context(@zone)
      three, sock = auth_context(@zone)

      now = time_travel(30)

      @zone.shutdown!

      eventually do
        two.last_saved_at.should eq now
        three.last_saved_at.should eq now
      end
    end

    it 'should spin zone down after inactivity' do
      Game.zones.count.should eq 1

      time_travel(Deepworld::Settings.zone.spin_down.minutes)

      eventually do
        @zone.reload
        Game.zones.count.should eq 0
        @zone.last_saved_at.should_not be_nil
        @zone.server_id.should be_nil
      end
    end

    it 'should not spin zone down before inactivity threshold' do
      Game.zones.count.should eq 1

      time_travel(Deepworld::Settings.zone.spin_down.minutes / 2)
      sleep(0.2)

      Game.zones.count.should eq 1
    end

  end


  describe 'meta blocks' do

    before(:each) do
      @zone = ZoneFoundry.create()
      @one, @o_sock = auth_context(@zone)
      @zone = Game.zones[@zone.id]

      @sign_code = Game.item('signs/wood-small').code
      @zone.set_meta_block 5, 5, @sign_code, @one, { 'a' => 'b' }
      @idx = 5 * 80 + 5
    end

    it 'should set meta blocks' do
      @zone.meta_blocks.size.should == 1
      @zone.meta_blocks.keys.should == [@idx]

      b = @zone.meta_blocks.values.first
      b.item.code.should == @sign_code
      b.player_id.should == @one.id.to_s
      b.should be_local
      b.data.should == { 'a' => 'b' }

      msg = Message.receive_one(@o_sock, only: :block_meta)
      msg.should_not be_blank
      msg.data.first.should == [5, 5, { 'i' => @sign_code, 'p' => @one.id.to_s, 'a' => 'b' }]
    end

    it 'should retrieve meta blocks' do
      b = @zone.get_meta_block(5, 5)
      b.item.code.should == @sign_code
      b.player_id.should == @one.id.to_s
      b.should be_local
      b.data.should == { 'a' => 'b' }
    end

    it 'should pack meta blocks' do
      p = MetaBlock.pack(@zone.meta_blocks)
      p.should == { @idx.to_s => { 'i' => @sign_code, 'p' => @one.id.to_s, 'a' => 'b' } }
    end

    it 'should unpack meta blocks' do
      p = MetaBlock.pack(@zone.meta_blocks)

      blocks = MetaBlock.unpack(@zone, p)
      blocks.size.should == 1
      blocks.keys.should == [@idx]

      b = blocks.values.first
      b.item.code.should == @sign_code
      b.player_id.should == @one.id.to_s
      b.should be_local
      b.data.should == { 'a' => 'b' }
    end

    describe 'indexing' do

      it 'should index teleports' do
        item = stub_item('teleporter', { 'meta' => 'global', 'use' => { 'teleport' => true } })
        @zone.update_block nil, 1, 1, FRONT, item.code
        @zone.indexed_meta_blocks[:teleporter].size.should eq 1
        @zone.indexed_meta_blocks[:teleporter].values.first.position.should eq Vector2[1, 1]
        @zone.teleporters_in_range(Vector2[3, 3], 5).size.should eq 1
      end

      it 'should index spawns' do
        item = stub_item('zone teleporter', { 'meta' => 'global', 'use' => { 'zone teleport' => true } })
        @zone.update_block nil, 1, 1, FRONT, item.code
        @zone.indexed_meta_blocks[:zone_teleporter].size.should eq 1
        @zone.indexed_meta_blocks[:zone_teleporter].values.first.position.should eq Vector2[1, 1]
        @zone.spawns_in_range(Vector2[3, 3], 5).size.should eq 1
      end

      it 'should index protected items' do
        item = stub_item('protector', { 'meta' => 'global', 'field' => 5 })
        @zone.update_block nil, 1, 1, FRONT, item.code
        @zone.indexed_meta_blocks[:field].size.should eq 1
        @zone.indexed_meta_blocks[:field].values.first.position.should eq Vector2[1, 1]
        @zone.protectors_in_range(Vector2[3, 3], 5).size.should eq 1
        @zone.protectors_in_range(Vector2[10, 10], 5).size.should eq 0
      end

    end

  end

  describe 'world teleporters', :with_a_zone_and_2_players do

    before(:each) do
      @zone.update_block nil, 0, 0, FRONT, Game.item_code('mechanical/zone-teleporter')
    end

    it 'should assign teleporters to an owner' do
      @zone.owners = [@one.id]
      @zone.own_portals
      @zone.meta_blocks[0].player_id.should eq @one.id.to_s
    end

    it 'should not assign teleporters if there is no owner' do
      @zone.own_portals
      @zone.meta_blocks[0].player_id.should be_blank
    end

  end

  describe 'clearing teleporters', :with_a_zone do
    it 'should clear teleporters at the edge' do
      @zone.update_block nil, 5, 5, FRONT, Game.item_code('mechanical/zone-teleporter')
      earth = Game.item_code('ground/earth')

      (5..7).each { |x| @zone.update_block nil, x, 3, FRONT, earth }
      (5..7).each { |x| @zone.update_block nil, x, 4, FRONT, earth }
      (6..7).each { |x| @zone.update_block nil, x, 5, FRONT, earth }

      @zone.clear_portals

      (5..7).each { |x| @zone.peek(x, 3, FRONT).should eq [0, 0]}
      (5..7).each { |x| @zone.peek(x, 4, FRONT).should eq [0, 0]}
      (6..7).each { |x| @zone.peek(x, 5, FRONT).should eq [0, 0]}
    end

    it 'should clear teleporters near the origin' do
      @zone.update_block nil, 1, 1, FRONT, Game.item_code('mechanical/zone-teleporter')
      Proc.new { @zone.clear_portals }.should_not raise_error
    end

    it 'should clear teleporters at the edge' do
      @zone.update_block nil, @zone.size.x - 1, @zone.size.y - 1, FRONT, Game.item_code('mechanical/zone-teleporter')
      Proc.new { @zone.clear_portals }.should_not raise_error
    end
  end


  describe 'environment' do

    before(:each) do
      @zone = ZoneFoundry.create()
      @one, @o_sock = auth_context(@zone)
      @two, @t_sock = auth_context(@zone)
      @zone = Game.zones[@zone.id]

      # GECK
      @geck_code = Game.item_code('mechanical/geck-tub')
      @zone.update_block nil, 2, 10, FRONT, @geck_code
      @zone.set_meta_block 2, 10, @geck_code
      @zone.instance_variable_set "@geck_meta_block", @zone.get_meta_block(2, 10)
      (3..6).each { |x| @zone.update_block nil, x, 10, FRONT, 0 }

      # Composter
      @composter_code = Game.item_code('mechanical/composter-chamber')
      @zone.update_block nil, 10, 10, FRONT, @composter_code
      @zone.set_meta_block 10, 10, @composter_code
      @zone.instance_variable_set "@composter_meta_block", @zone.get_meta_block(2, 10)
    end

    describe 'finding machines' do
      before(:each) do
        extend_player_reach @one
      end

      it 'should update zone status and notify players when I find a purifier piece' do
        test_part_discovery 'mechanical/geck-hoses', 'purifier', 'p'
      end

      it 'should update zone status and notify players when I find a composter piece' do
        test_part_discovery 'mechanical/composter-cover', 'composter', 'c'
      end

      def test_part_discovery(part_name, description, status_code)
        part = Game.item_code(part_name)
        chest = Game.item_code('containers/chest')
        @zone.update_block nil, 1, 1, FRONT, chest
        @zone.set_meta_block 1, 1, chest, nil, { '$' => part }

        cmd = BlockUseCommand.new([1, 1, FRONT, nil], @one.connection)
        cmd.execute!

        msg = Message.receive_one(@o_sock, only: :notification)
        msg.data.first.should be_a(Hash)
        msg.data.first['t'].should =~ /discovered/
        msg.data.first['t'].should =~ /#{description}/
        msg.data.first['i'].should =~ /#{part_name}/
        msg.data.last.should == 10

        msg = Message.receive_one(@t_sock, only: :notification)
        msg.data.first.should =~ /discovered/
        msg.data.first.should =~ /#{description}/
        msg.data.last.should == 11

        msg = Message.receive_one(@o_sock, only: :zone_status)
        msg.data.first['machines'][status_code].should eq [part]
      end

    end

    describe 'active geck' do

      before(:each) do
        @zone.machines_discovered[:geck] = [@geck_code] * 8
        @zone.should be_purifier_complete
      end

      it 'should get less acidic if the purifier is active and open' do
        @zone.should be_purifier_active

        acidity = @zone.acidity
        @zone.process_purifier 3600.0
        @zone.acidity.should < acidity
      end

    end

    describe 'active composter' do

      before(:each) do
        @zone.machines_discovered[:composter] = [Game.item_code('mechanical/composter-cover')] * 8
        @zone.should be_composter_complete

        extend_player_reach @one
      end

      it 'should let me exchange inventory for composted earth' do
        earth = Game.item_code('ground/earth')
        giblets = Game.item_code('ground/giblets')
        compost = Game.item_code('ground/earth-compost')

        @one.inv.add earth, 25
        @one.inv.add giblets, 25
        msg = BlockUseCommand.new([10, 10, FRONT, nil], @one.connection)
        msg.execute!
        msg.errors.should == []

        @one.inv.quantity(earth).should eq 15
        @one.inv.quantity(giblets).should eq 22
        @one.inv.quantity(compost).should eq 1

        msg = Message.receive_one(@o_sock, only: :inventory)
        msg.data.first.should == { earth.to_s => [15, 'i', -1], giblets.to_s => [22, 'i', -1], compost.to_s => [1, 'i', -1] }
      end

      it 'should not let me exchange inventory for composted earth if I do not have enough inventory' do
        msg = BlockUseCommand.new([10, 10, FRONT, nil], @one.connection)
        msg.execute!
        msg.errors.should == []

        msg = Message.receive_one(@o_sock, only: :notification)
        msg.data.first.should =~ /You need/
      end
    end

  end

  describe 'active chunks' do

    before(:each) do
      @zone = ZoneFoundry.create()
      @one, @o_sock = auth_context(@zone)
      @zone = Game.zones[@zone.id]

      @one.position = Vector2.new(10.534, 8.610)
      @one.add_active_indexes [0, 1]
    end

    pending 'should provide active chunks based on player active chunks' do
      @zone.active_chunk_indexes.should =~ {0=>true, 1=>true}
    end

    it 'should provide immediate chunks based on areas immediately around players' do
      @zone.immediate_chunk_indexes.should == {0=>true, 1=>true}
    end

    it 'should provide occupied chunks based on chunks that players are currently in' do
      @zone.occupied_chunk_indexes.should =~ [0]
    end

  end

  describe 'membership' do
    before(:each) do
      @one = PlayerFoundry.create
    end

    it 'should allow you to play in a public zone' do
      zone = ZoneFoundry.create(private: false)

      zone.can_play?(@zone).should be_true
    end

    it 'should not allow you to play in a private zone' do
      zone = ZoneFoundry.create(private: true)

      zone.can_play?(@one).should be_false
    end

    it 'should let you play in a private zone that you are an owner of' do
      zone = ZoneFoundry.create(private: true, owners: [@one.id])

      zone.can_play?(@one).should be_true
    end

    it 'should let you play in a private zone that you are a member of' do
      zone = ZoneFoundry.create(private: true, members: [@one.id])

      zone.can_play?(@one).should be_true
    end

  end

  it 'should simulate the world a little bit' do
    @zone = ZoneFoundry.create(last_active_at: Time.now - 1.day, acidity: 0)
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    @zone.growth.cycles.should > 5
  end


  #DO THIS
  #DO THIS
  #DO THIS
  #DO THIS
  # TODO
  pending 'should properly handle a bad file' do
    # Create a zone with a bad file
    @zone = ZoneFoundry.create(data_path: :junk)

    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]

    # Should be setup correctly
    @zone.last_saved_at.should be_nil
    @zone.server_id.should eq Game.document_id
  end



  describe 'anomalies' do

    before(:each) do
      # 700 x 400 blocks = 35 x 20 chunks = 700 chunks
      @zone = ZoneFoundry.create(data_path: 'large', size: Vector2.new(700, 400))
      @zone.chunk_width.should == 35
      @zone.chunk_height.should == 20
    end

    it 'should not take a dump when invalid chunks are accessed' do
      @zone.kernel.chunk(0, false).should_not be_blank
      @zone.kernel.chunk(450, false).should_not be_blank
      expect { @zone.kernel.chunk(-1) }.to raise_error
      expect { @zone.kernel.chunk(701) }.to raise_error

      @zone.get_chunk(0).should_not be_blank
      @zone.get_chunk(450).should_not be_blank
      @zone.get_chunk(-1).should be_nil
      @zone.get_chunk(701).should be_nil
    end

  end

  describe 'queueing', :with_a_zone_and_2_players do

    before(:each) do
      @bomb = Game.item('mechanical/bomb')
      @zone.add_block_timer Vector2[10, 10], 3, ['bomb', 10], @one
      time = Time.now
      Time.stub(:now).and_return(time + 10.seconds)
    end

    it 'should queue explosions' do
      @zone.stub(:explode).and_raise('Exploded!')
      Proc.new { @zone.process_block_timers }.should raise_error
    end

    it 'should remove timers after they activate' do
      @zone.process_block_timers
      @zone.block_timers_count.should eq 0
    end

    it 'should remove timers if a block is mined' do
      @zone.update_block nil, 10, 10, FRONT, 0
      @zone.block_timers_count.should eq 0
    end

  end

  describe 'explosions', :with_a_zone_and_2_players do

    def prep_for_explosion
      @wood ||= stub_item('wood', { 'toughness' => 1, 'karma' => -2 }).code
      @back ||= stub_item('back', { 'toughness' => 1, 'karma' => -2 }).code
      @iron ||= stub_item('iron', { 'toughness' => 10, 'karma' => -2 }).code

      (0..19).each do |x|
        (0..19).each do |y|
          @zone.update_block nil, x, y, BACK, @back, 0, @one
          @zone.update_block nil, x, y, FRONT, @wood, 0, @one unless x == 10
        end
      end

      # One reinforced iron to block explosion
      @zone.update_block nil, 9, 10, FRONT, @iron
    end

    before(:each) do
      prep_for_explosion
    end

    it 'should explode performantly' do
      2.times do
        prep_for_explosion
        block = 0
        (20..79).each do |x|
          (0..19).each do |y|
            if block < 250
              @zone.update_block @one.entity_id, x, y, FRONT, Game.item_code('mechanical/dish-micro')
            else
              @zone.update_block @one.entity_id, x, y, FRONT, Game.item_code('signs/copper-small')
            end
            block += 1
          end
        end
        bench = Benchmark.measure do
          @zone.explode Vector2[8, 8], 8
        end
        ms = (bench.real * 1000).to_i
        #p "Exploded in: #{ms}ms"
        ms.should < 500
      end
    end

    it 'should explode' do
      10.times do
        prep_for_explosion

        @zone.explode Vector2[10, 10], 8

        @zone.peek(13, 10, FRONT).should eq [0, 0]
        @zone.peek(13, 10, BACK).should eq [0, 0]
        @zone.peek(10, 10, FRONT).should eq [0, 0]
        @zone.peek(10, 10, BACK).should eq [0, 0]
        @zone.peek(10, 9, FRONT).should eq [0, 0]
        @zone.peek(10, 9, BACK).should eq [0, 0]
        @zone.peek(9, 9, FRONT).should eq [0, 0]
        @zone.peek(9, 9, BACK).should eq [0, 0]
        @zone.peek(8, 8, FRONT).should eq [0, 0]
        @zone.peek(8, 8, BACK).should eq [0, 0]

        # Reinforced block protection
        @zone.peek(9, 10, FRONT).should eq [@iron, 0]
        @zone.peek(9, 10, BACK).should eq [@back, 0]
        @zone.peek(8, 10, FRONT).should eq [@wood, 0]
        @zone.peek(8, 10, BACK).should eq [@back, 0]
      end
    end

    it 'should clobber karma' do
      @zone.explode Vector2[10, 10], 5, @two
      @two.karma.should < -50
    end

    it 'should not explode items protected by others' do
      extend_player_reach @one
      @dish = Game.item_code('mechanical/dish')
      add_inventory(@one, @dish, 10)

      @zone.update_block @one.entity_id, 10, 10, FRONT, @dish
      @zone.block_protected?(Vector2[13, 10], @two).should be_true

      @zone.explode Vector2[10, 10], 5, @two

      @zone.peek(13, 10, FRONT).should eq [@wood, 0]
      @zone.peek(13, 10, BACK).should eq [@back, 0]
    end

    it 'should not explode my own teleporters, dishes, and other fielded items' do
      extend_player_reach @one
      @dish = Game.item_code('mechanical/dish')
      @teleporter = Game.item_code('mechanical/teleporter')
      add_inventory(@one, @dish, 10)
      add_inventory(@one, @teleporter, 10)

      @zone.update_block @one.entity_id, 11, 11, FRONT, @dish
      @zone.update_block @one.entity_id, 12, 12, FRONT, @teleporter

      @zone.explode Vector2[10, 10], 5, @one

      @zone.peek(11, 11, FRONT).should eq [@dish, 0]
      @zone.peek(12, 12, FRONT).should eq [@teleporter, 0]
    end

    it 'should not blow up containers with special items in them' do
      @chest = Game.item_code('containers/chest')
      @zone.update_block nil, 11, 11, FRONT, @chest, 1
      @zone.set_meta_block 11, 11, @chest, nil, { '$' => 881 }

      @zone.explode Vector2[10, 10], 5, @one

      @zone.peek(11, 11, FRONT).should eq [@chest, 1]
      @zone.get_meta_block(11, 11).should be_special_item
    end

  end

  describe 'accessibility' do
    before(:each) do
      @premium = ZoneFoundry.create(premium: 'true', biome: 'deep')
    end

    it 'should report a premium zone as premium' do
      player = PlayerFoundry.create(premium: false)
      @premium.accessibility_for(player).should eq 'p'
    end

    it 'should report my owned premium zone as accessible' do
      player = PlayerFoundry.create
      @premium.add_owner player

      @premium.accessibility_for(player).should eq 'a'
    end
  end

  describe 'file versioning' do
    before(:each) do
      @time = stub_date Time.utc(2013, 1, 31, 14, 30) # 1:30
    end

    describe 'with a zone that''s being versioned in the NEW way' do
      it 'should set file version to 1 when initially persisted' do
        @zone = ZoneFoundry.create()

        @zone.file_version.should eq 0
        @zone.file_versioned_at.should be_within(1.second).of Time.now
        @zone.persist!
      end

      it 'should rotate to version 1 immediately if version is 0' do
        @zone = ZoneFoundry.create(file_version: 0, file_versioned_at: Time.now)
        @zone.persist!

        @zone.file_version.should eq 1
        @zone.file_versioned_at.should be_within(1.second).of Time.now
      end

      it 'should keep zone version the same if same day' do
        @zone = ZoneFoundry.create(file_version: 1, file_versioned_at: Time.now)
        @zone.persist!

        time_travel 9.hours + 29.minutes
        @zone.persist!

        @zone.file_version.should eq 1
        @zone.file_versioned_at.should eq @time
      end

      it 'should rotate to the next zone version after 24 hrs' do
        @zone = ZoneFoundry.create(file_version: Deepworld::Settings.versioning.history - 1, file_versioned_at: Time.now)
        @zone.persist!

        persisted_at = time_travel 9.hours + 30.minutes
        @zone.persist!

        @zone.file_version.should eq Deepworld::Settings.versioning.history
        @zone.file_versioned_at.should eq persisted_at
      end

      it "should rotate from zone version #{Deepworld::Settings.versioning.history} back to 1" do
        @zone = ZoneFoundry.create()
        first = time_travel 1.minute
        @zone.persist!

        Deepworld::Settings.versioning.history.times.each do
          second = time_travel 24.hours
          @zone.persist!
        end

        @zone.file_version.should eq 1
      end

      it "should capture the history for a zone version" do
        @zone = ZoneFoundry.create(file_version: Deepworld::Settings.versioning.history - 1, file_versioned_at: Time.now)
        @zone.persist!

        persisted_at = time_travel 9.hours + 30.minutes
        @zone.persist!

        @zone.file_version.should eq Deepworld::Settings.versioning.history
        @zone.file_versioned_at.should eq persisted_at
      end

      it 'it should provide the proper versioned data path' do
        @zone = ZoneFoundry.create(file_version: 6, file_versioned_at: Time.now)
        @zone.versioned_data_path.split('/').last.should eq "bunker.6.zone"
      end
    end
  end

end
