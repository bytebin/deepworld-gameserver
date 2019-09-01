require 'spec_helper'

describe Guild do
  describe 'Guild creation' do
    def validate_guild(guild)
      validated = nil
      guild.validate do |g|
        validated = g
      end

      eventually { validated.should_not be_nil }
      validated
    end

    before(:each) do
      with_a_zone
      with_a_player(@zone)
      Game.items['signs/guild'].field = 1

      @existing = GuildFoundry.create({zone_id: @zone.id, name: 'Cheesy Poofs', short_name: 'CPZ', leader_id: @one.id})
    end

    describe 'a new guild' do
      it 'should not a allow a duplicate guild name' do
        guild = Guild.new(zone_id: @zone.id, name: 'Cheesy Poofs', short_name: 'BLOOP')

        guild = validate_guild(guild)
        guild.errors.count.should eq 1
        guild.errors.first.should match /Guild name/
      end

      it 'should not allow duplicate short name' do
        guild = Guild.new(zone_id: @zone.id, name: 'Bloopdy Bloops', short_name: 'CPZ')

        guild = validate_guild(guild)
        guild.errors.count.should eq 1
        guild.errors.first.should match /Short name/
      end
    end

    describe 'an existing guild' do
      before(:each) do
        @two = register_player(@zone)
        @newguild = GuildFoundry.create({zone_id: @zone.id, leader_id: @two.id})
      end

      it 'should not allow duplicate guild name' do
        @newguild.name = 'Cheesy Poofs'

        guild = validate_guild(@newguild)
        guild.errors.count.should eq 1
        guild.errors.first.should match /Guild name/
      end

      it 'should not allow duplicate short name' do
        @newguild.short_name = 'CPZ'

        guild = validate_guild(@newguild)
        guild.errors.count.should eq 1
        guild.errors.first.should match /Short name/
      end

      it 'should set guild metadata' do
        @newguild.should_not be_complete
        @newguild.apply_metadata({"gn"=>"Guild name", "gsn"=>"shortz", "c1"=>"620f06", "c2"=>"4b393f", "c3"=>"465c40", "c4"=>"620c06", "s"=>"signs/crests/book", "sc"=>"1a1816"})
        @newguild.should be_complete

        validate_guild(@newguild)

        @newguild.errors.count.should eq 0
        @newguild.name.should eq "Guild name"
        @newguild.short_name.should eq "shortz"
        @newguild.color1.should eq "620f06"
        @newguild.color2.should eq "4b393f"
        @newguild.color3.should eq "465c40"
        @newguild.color4.should eq "620c06"
        @newguild.sign_color.should eq "1a1816"
        @newguild.sign.should eq "signs/crests/book"
      end
    end
  end

  describe 'With a guild' do
    before(:each) do
      with_a_zone(data_path: :twentyempty)
      with_3_players(@zone, position: Vector2[6,6])

      @guild = GuildFoundry.create({zone_id: @zone.id, position: Vector2[5,5]})
      @guild.set_leader @one
      @guild.add_member @two
      @guild.add_member @three

      Message.receive_one(@one.socket, only: :notification).data[0].should match /is now a member/
      Message.receive_one(@one.socket, only: :notification).data[0].should match /is now a member/
      Message.receive_one(@two.socket, only: :notification).data[0].should match /are now a member/
      Message.receive_one(@three.socket, only: :notification).data[0].should match /are now a member/
    end

    it 'should not allow guild commands for non-members' do
      rejected = /Sorry, you are not a member of a guild./

      n00b, socket = auth_context(@zone)
      n00b.socket = socket

      console!(n00b, :ghelp).data[0].should match rejected
      console!(n00b, :ginfo).data[0].should match rejected
      console!(n00b, :ginvite, [@three.name]).data[0].should match rejected
      console!(n00b, :gremove, [@three.name]).data[0].should match rejected
      console!(n00b, :gleader, [@three.name]).data[0].should match rejected
      console!(n00b, :gquit).data[0].should match rejected
    end

    it 'should not allow guild leader commands for members' do
      rejected = /Sorry, you are not a guild leader./

      console!(@two, :ginvite, [@three.name]).data[0].should match rejected
      console!(@two, :gremove, [@three.name]).data[0].should match rejected
      console!(@two, :gleader, [@three.name]).data[0].should match rejected
    end

    it 'should send a command list dialog for a member' do
      msg = console! @one, :ghelp

      msg.should be_message :notification
      msg.data[0].to_s.should match /Guild Help/
    end

    it 'should display guild info for an owner or member' do
      [@one, @two].each do |p|
        msg = console! p, :ginfo
        msg.should be_message :notification

        msg.data[0]["sections"].first["title"].should eq "#{@guild.name} [#{@guild.short_name}]"
        msg.data[0]["sections"].last["text"].should == [@two, @three].map(&:name).sort.join(", ")
      end
    end

    it 'should not explode showing info when the zone and position have been niled' do
      done = false
      @guild.clear_location do
        done = true
      end
      eventually { done.should be_true }

      msg = console! @one, :ginfo
      msg.should be_message :notification
      msg.data[0]["sections"][2]["text"].should eq "Home World: None"
    end

    describe 'inviting' do

      it 'should yell about an unknown player' do
        msg = console! @one, :ginvite, ['whoever']

        msg.should be_message :notification
        msg.data[0].to_s.should match /Player whoever not found./
      end

      it 'should yell about pre-guilded player' do
        msg = console! @one, :ginvite, [@two.name]

        msg.should be_message :notification
        msg.data[0].to_s.should match /Sorry, #{@two.name} already belongs to a guild./
      end

      it 'it should not allow a player invitation out of range' do
        n00b = register_player(@zone, {position: Vector2[19,19]})
        msg = console! @one, :ginvite, [n00b.name]
        msg.should be_message :notification
        msg.data[0].to_s.should match /Please meet #{n00b.name} at the guild obelisk to invite them./
      end

      it 'should invite a player' do
        n00b = register_player(@zone, {position: Vector2[8,8]})
        console! @one, :ginvite, [n00b.name]

        dialog_id, sections = receive_dialog(n00b.socket)
        sections[0]["title"].should eq 'Guild Membership'
      end

      it 'should accept a guild invitation' do
        n00b = register_player(@zone, {position: Vector2[8,8]})
        n00b.guild.should be_nil
        console! @one, :ginvite, [n00b.name]

        respond_to_dialog n00b

        n00b.guild.id.should eq @guild.id
      end

    end

    describe 'leading' do
      it 'should invite a member to lead the guild' do
        console! @one, :gleader, [@two.name], true

        dialog_id, sections = receive_dialog(@two.socket)
        sections[0]["title"].should eq 'Guild Leadership'
      end

      it 'should make a member the new leader' do
        @guild.leader_id.should eq @one.id

        console! @one, :gleader, [@two.name], true
        respond_to_dialog @two

        # Post
        @guild.leader_id.should eq @two.id
        @guild.members.should =~ [@one.id, @two.id, @three.id]
      end
    end

    describe 'removing' do

      it 'should yell about an unknown player' do
        msg = console! @one, :gremove, ['whoever']

        msg.should be_message :notification
        msg.data[0].to_s.should match /Player whoever not found./
      end

      it 'should yell about a player of another guild' do
        @guild = GuildFoundry.create({zone_id: @zone.id})
        @guild.set_leader @two

        msg = console! @one, :gremove, [@two.name]

        msg.should be_message :notification
        msg.data[0].to_s.should match /Sorry, #{@two.name} does not belong to your guild./
      end

      it 'should not crash when removing an offline player' do
        player = PlayerFoundry.create
        @guild.add_member player

        msg = console! @one, :gremove, [player.name]
        msg.errors.should be_blank

        eventually { @guild.members.should eq [@one.id, @two.id, @three.id] }
      end
    end

    describe 'leader' do

      it 'should yell about an unknown player' do
        msg = console! @one, :gleader, ['whoever'], true

        msg.should be_message :notification
        msg.data[0].to_s.should match /Player whoever not found./
      end

      it 'should yell about pre-guilded player' do
        @guild = GuildFoundry.create({zone_id: @zone.id})
        @guild.set_leader @two

        msg = console! @one, :gleader, [@two.name], true

        msg.should be_message :notification
        msg.data[0].to_s.should match /Sorry, #{@two.name} already belongs to a guild./
      end

      it 'should fail to invite an offline player to lead the guild' do
        n00b = register_player
        disconnect(n00b.socket)

        msg = console! @one, :gleader, [n00b.name], true
        msg.data[0].to_s.should match /Please meet #{n00b.name} at the guild obelisk to pass leadership./
      end

      it 'should invite a player to lead the guild' do
        n00b = register_player
        console! @one, :gleader, [n00b.name], true

        dialog_id, sections = receive_dialog(n00b.socket)
        sections[0]["title"].should eq 'Guild Leadership'
      end


      it 'should accept a guild leadership' do
        console! @one, :gleader, [@two.name], true

        # Pre
        @two.guild.leader_id.should eq @one.id

        respond_to_dialog @two

        # Post
        @two.guild.leader_id.should eq @two.id
      end

      it 'should refuse a guild leadership' do
        console! @one, :gleader, [@two.name]

        # Pre
        @two.guild.leader_id.should eq @one.id

        # Do nothing (cancel)

        # Post
        @two.guild.leader_id.should eq @one.id
      end

    end

    describe "quitting" do
      it 'should allow a player to quit a guild' do
        msg = console! @two, :gquit, [], true

        GuildFoundry.reload(@guild)

        @two.guild.should be_nil
        @guild.members.should_not include @two.id
      end

      it 'should not allow a guild leader to quit a guild' do
        msg = console! @one, :gquit

        msg.should be_message :notification
        msg.data[0].to_s.should match /You'll need to designate a new guild leader before quitting./
      end
    end
  end

  describe "obelisk" do
    before(:each) do
      eventually { collection(:guild).count.should eq 0 }

      with_a_zone(data_path: :twentyempty)
      with_2_players(@zone, {inventory: { '915' => [ 5, 'h', 1 ] }, position: [5, 5]})
    end

    it 'should create a guild when i place an obelisk' do
      place_obelisk(@one, 5, 5).errors.should eq []

      eventually { collection(:guilds).count.should eq 1 }

      guild = collection(:guilds).find_one
      guild['leader_id'].should eq @one.id
      guild['members'].should eq [@one.id]
      guild['position'].should eq [5,5]
      guild['zone_id'].should eq @zone.id
    end

    it 'should send no notifications when i place an obelisk' do
      place_obelisk(@one, 5, 5).errors.should eq []

      Message.receive_many(@one.socket, only: :notification).should eq []
    end

    it 'should not allow me to place a second obelisk' do
      place_obelisk(@one, 5, 5).errors.should eq []
      eventually { collection(:guilds).count.should eq 1 }

      cmd = place_obelisk(@one, 8, 5)
      cmd.errors.count.should eq 1
      cmd.errors.first.should match(/already exists/)
    end

    it 'should allow two players to place obelisks' do
      place_obelisk(@one, 5, 5).errors.should eq []
      place_obelisk(@two, 8, 5).errors.should eq []

      eventually { collection(:guilds).count.should eq 2 }
    end

    it 'should not allow a guild member to place an obelisk' do
      @guild = GuildFoundry.create({zone_id: @zone.id})
      @guild.set_leader @one
      @guild.add_member @two

      cmd = place_obelisk(@two, 5, 5)
      cmd.errors.count.should eq 1
      cmd.errors.first.should match(/already belong/)
    end

    it 'should allow me to place a mined obelisk' do
      place_obelisk(@one, 5, 5).errors.should eq []
      place_obelisk(@one, 8, 5).errors.count.should eq 1

      eventually {
        collection(:guilds).count.should eq 1
        collection(:guilds).find_one['position'].should eq [5, 5]
      }

      mine_obelisk(@one, 5, 5).errors.should eq []
      place_obelisk(@one, 8, 5).errors.should eq []

      eventually {
        collection(:guilds).count.should eq 1
        collection(:guilds).find_one['position'].should eq [8, 5]
      }
    end

    it 'should set the new leader as the block and metablock owner' do
      @guild = GuildFoundry.create({position: nil, zone_id: nil})
      @guild.set_leader @one
      place_obelisk(@one, 5, 5).errors.should eq []

      @zone.get_meta_block(5, 5).player_id.should eq @one.id.to_s
      @zone.block_owner(5, 5, FRONT).should eq @one.id.digest

      console! @one, :gleader, [@two.name], true
      respond_to_dialog @two

      @zone.block_owner(5, 5, FRONT).should eq @two.id.digest
      @zone.get_meta_block(5, 5).player_id.should eq @two.id.to_s
    end

    def place_obelisk(player, x = 5, y = 5)
      command player, :block_place, [x, y, FRONT, 915, 0]
    end

    def mine_obelisk(player, x, y)
      command player, :block_mine, [x, y, FRONT, 915, 0]
    end
  end
end
