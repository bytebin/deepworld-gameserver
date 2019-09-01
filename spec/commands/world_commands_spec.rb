require 'spec_helper'

describe 'WorldCommands' do
  describe 'With an owned world' do
    before(:each) do
      with_a_zone
      with_3_players(@zone)
      @zone.owners = [@one.id]
      @one.owned_zones = [@zone.id]
    end

    describe 'non owners' do
      it 'should not allow world commands for non-owners' do
        rejected = /Sorry, you do not own this world./

        command @two, :console, ['whelp', []]
        msg = Message.receive_one(@two.socket, only: :notification).data[0].should match rejected

        command @two, :console, ['winfo', []]
        msg = Message.receive_one(@two.socket, only: :notification).data[0].should match rejected

        command @two, :console, ['wrecode', []]
        msg = Message.receive_one(@two.socket, only: :notification).data[0].should match rejected

        command @two, :console, ['wadd', [@one.name]]
        msg = Message.receive_one(@two.socket, only: :notification).data[0].should match rejected

        command @two, :console, ['wremove', [@two.name]]
        msg = Message.receive_one(@two.socket, only: :notification).data[0].should match rejected
      end
    end

    describe 'world list' do
      it 'should send a command list dialog for the owner' do
        command! @one, :console, ['whelp', []]
        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should be_message :notification

        msg.data[0]["sections"][0]["title"].should match /Private World Help/
      end
    end

    describe "world info" do
      it 'should display zone info for the owner' do
        @zone.members = [@two.id, @three.id]

        command! @one, :console, ['winfo', []]
        msg = receive_msg!(@one, :dialog)
        msg.data.to_s.should =~ /World Info/
        msg.data.to_s.should include([@one, @two, @three].map(&:name).sort.join(", "))
      end
    end

    describe "world add" do
      it 'should add a member to the zone' do
        @two.update name: "Two Words", name_downcase: 'two words'
        command! @one, :console, ['wadd', ['Two', 'Words']]

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should be_message :notification
        msg.data[0].should match /Two Words has been added./

        @zone.members.should eq [@two.id]
      end

      it 'should add a missive to the invited player' do
        command! @one, :console, ['wadd', @two.name]

        eventually {
          missive = collection(:missive).find({ 'player_id' => @two.id }).to_a.last
          missive['message'].should =~ /#{@one.name} has added you as a member of #{@zone.name}!/
        }
      end

      it 'should yell about an unknown player' do
        command! @one, :console, ['wadd', ['Jimmy Whothehell']]

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should be_message :notification
        msg.data[0].should match /Player Jimmy Whothehell not found./
        msg.data[1].should eq 1
      end

      it 'should instruct how to use if player unspecified' do
        command @one, :console, ['wadd', []]

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should be_message :notification
        msg.data[0].should match /Incorrect parameters for wadd./
        msg.data[1].should eq 1
      end
    end

    describe "world remove" do
      def add_member(zone, player)
        zone.add_member(player)
        eventually { zone.members.should include player.id }
      end

      it 'should remove a playing member from the zone and kick them' do
        add_member(@zone, @two)

        command! @one, :console, ['wremove', [@two.name]]

        Message.receive_one(@one.socket, only: :notification).data[0].should match /#{@two.name} has been removed./
        @zone.members.should eq []

        Message.receive_one(@two.socket, only: :kick).should be_message(:kick)
        @two.member_zones.should eq []
        @two.zone_id.should eq nil
        @two.spawn_point.should eq nil
        @two.position.should eq nil
      end

      it 'should remove a non playing member from a zone' do
        player = PlayerFoundry.create(zone_id: @zone.id, position: Vector2[5,5], spawn_point: Vector2[8,8])
        add_member(@zone, player)

        command! @one, :console, ['wremove', [player.name]]

        Message.receive_one(@one.socket, only: :notification).data[0].should match /#{player.name} has been removed./

        @zone.members.should eq []

        player = PlayerFoundry.reload(player)
        player.member_zones.should eq []
        player.zone_id.should eq nil
        player.spawn_point.should eq nil
        player.position.should eq nil
      end

      it 'should remove a non playing member from a zone they are not assigned to currently' do
        player = PlayerFoundry.create(position: Vector2[5,5], spawn_point: Vector2[8,8], zone_id: BSON::ObjectId('50ff11154aae37397d00002d'))
        add_member(@zone, player)

        command! @one, :console, ['wremove', [player.name]]
        Message.receive_one(@one.socket, only: :notification).data[0].should match /#{player.name} has been removed./

        @zone.members.should eq []
        player = PlayerFoundry.reload(player)
        player.member_zones.should eq []
        player.zone_id.should_not be_nil
        player.spawn_point.should eq Vector2[8,8]
        player.position.should eq Vector2[5,5]
      end

      it 'should yell about an unknown player' do
        command! @one, :console, ['wremove', ['Jimmy Whothehell']]

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should be_message :notification
        msg.data[0].should match /Player Jimmy Whothehell not found./
        msg.data[1].should eq 1
      end

      it 'should instruct how to use if player unspecified' do
        command @one, :console, ['wremove', []]

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should be_message :notification
        msg.data[0].should match /Incorrect parameters for wremove./
        msg.data[1].should eq 1
      end
    end

    describe 'world recode' do
      it 'should change the zone code for a zone' do
        previous = @zone.entry_code

        command! @one, :console, ['wrecode', []]
        Message.receive_one(@one.socket, only: :notification).data[0].should match /Your world entry code has been changed to/

        @zone.entry_code.should_not eq previous
        @zone.entry_code.length.should eq 7
        @zone.entry_code[0].should eq 'z'
      end
    end

    describe 'world rename' do
      it 'should change the name of a zone' do
        command! @one, :console, ['wrename', ['New world']]

        eventually do
          @zone.name.should eq 'New world'
          Message.receive_one(@one.socket, only: :kick).data[0].should eq 'Renamed world'
        end
      end

      it 'should not allow a name less than 5 characters' do
        old_name = @zone.name
        command @one, :console, ['wrename', ['Shor']]

        @zone.name.should eq old_name
        Message.receive_one(@one.socket, only: :kick).should be_nil
      end

      it 'should not change the name to an obscene name' do
        old_name = @zone.name
        command @one, :console, ['wrename', ['New Shit']]

        @zone.name.should eq old_name
        Message.receive_one(@one.socket, only: :kick).should be_nil
      end

      it 'should not change the name to a non alphanumeric name' do
        old_name = @zone.name
        command @one, :console, ['wrename', ['YA_Y!!']]

        @zone.name.should eq old_name
        Message.receive_one(@one.socket, only: :kick).should be_nil
      end

      it 'should strip spaces from a name' do
        command! @one, :console, ['wrename', ['   my stupid world  ']]

        eventually do
          @zone.name.should eq 'my stupid world'
        end
      end

      it 'should not allow a change to a name that already exists' do
        ZoneFoundry.create(name: 'Superworld')
        command!(@one, :console, ['wrename', ['superworld']])
        eventually do
          msg = Message.receive_one(@one.socket, only: :notification)
          msg.should_not be_blank
          msg.data.to_s.should =~ /already/
        end
      end

      it 'should persist the command history of a name change' do
        stub_date(time = Time.now)
        command! @one, :console, ['wrename', ['New world']]

        eventually { @zone.command_history.should == {"world_rename_command"=>[1, time.to_i]} }

        shutdown_zone @zone
        eventually do
          collection(:zone).find_one(name: @zone.name)['command_history'].should == {"world_rename_command"=>[1, time.to_i]}
        end
      end

      it 'should not allow a second execution in a time period' do
        stub_date(time = Time.now)
        command! @one, :console, ['wrename', ['New world']]

        eventually do
          stub_date(time + 1.day - 10.seconds)
          cmd = command(@one, :console, ['wrename', ['Nope']])
          cmd.errors.should_not eq []
          @zone.name.should eq 'New world'
        end
      end

      it 'should allow a second execution outside the required period' do
        stub_date(time = Time.now)
        command! @one, :console, ['wrename', ['New world']]

        stub_date time + 1.day + 30.seconds
        command! @one, :console, ['wrename', ['Changed']]

        eventually do
          @zone.name.should eq 'Changed'
        end
      end
    end

    describe 'world pvp' do
      it 'should change the zone to pvp' do
        command! @one, :console, ['wpvp', ['on']]

        eventually {
          collection(:zone).find_one(name: @zone.name)['pvp'].should eq true
        }
      end

      it 'should change the zone from pvp' do
        @zone.update pvp: true
        command! @one, :console, ['wpvp', ['off']]

        eventually {
          collection(:zone).find_one(name: @zone.name)['pvp'].should eq false
        }
      end
    end

    describe 'world public command' do
      it 'should change the zone to public' do
        @zone.update private: true
        command! @one, :console, ['wpublic', ['on']]

        eventually {
          zone = collection(:zone).find_one(name: @zone.name)
          zone['private'].should eq false
        }
      end

      it 'should default to protected when going public' do
        @zone.update private: true, protection_level: nil
        command! @one, :console, ['wpublic', ['on']]

        eventually {
          zone = collection(:zone).find_one(name: @zone.name)
          zone['protection_level'].should eq 10
        }
      end

      it 'should change the zone from pvp' do
        @zone.update private: false
        command! @one, :console, ['wpublic', ['off']]

        eventually {
          collection(:zone).find_one(name: @zone.name)['private'].should eq true
        }
      end
    end

    describe 'world protected command' do
      it 'should change the zone to non-protected' do
        @zone.update protection_level: 10
        command! @one, :console, ['wprotected', ['off']]
        dialog = receive_msg(@one, :dialog)
        command! @one, :dialog, [dialog.data.first, []]

        eventually {
          zone = collection(:zone).find_one(name: @zone.name)
          zone['protection_level'].should eq 0
        }
      end

      it 'should not allow users to change the zone to protected' do
        Message.receive_many(@one.socket)
        @zone.update protection_level: 0
        command @one, :console, ['wprotected', ['on']]

        receive_msg!(@one, :notification).data.to_s.should =~ /cannot/
        zone = collection(:zone).find_one(name: @zone.name)
        zone['protection_level'].should eq 0
      end
    end

    describe 'world ban command' do

      before(:each) do
        @offline = PlayerFoundry.create
      end

      it 'should mark an online player banned' do
        command! @one, :console, ['wban', [@two.name, 60]]
        @zone.bannings[@two.id.to_s].should eq (Time.now + 60.minutes).to_i
      end

      it 'should mark an offline player banned' do
        command! @one, :console, ['wban', [@offline.name, 60]]
        eventually do
          @zone.bannings[@offline.id.to_s].should eq (Time.now + 60.minutes).to_i
        end
      end

      it 'should not allow long-term bans' do
        command(@one, :console, ['wban', [@two.name, 3000]]).should_not be_valid
        @zone.bannings[@two.id.to_s].should be_nil
      end

      it 'should not allow permabans if online bannee has placed protected items' do
        item = stub_item('protecty', 'field' => 1, 'meta' => 'local')
        @zone.update_block nil, 5, 5, FRONT, item.code, 0, @two

        command! @one, :console, ['wban', [@two.name, 'forever']]
        receive_msg!(@one, :notification).data.to_s.should =~ /protected/
        @zone.bannings[@two.id.to_s].should be_nil
      end

      it 'should not allow permabans if offline bannee has placed protected items' do
        item = stub_item('protecty', 'field' => 1, 'meta' => 'local')
        @zone.update_block nil, 5, 5, FRONT, item.code, 0, @offline

        command! @one, :console, ['wban', [@offline.name, 'forever']]

        server_wait
        receive_msg!(@one, :notification).data.to_s.should =~ /protected/
        @zone.bannings[@offline.id.to_s].should be_nil
      end

      it 'should allow permabans if online bannee has not placed protected items' do
        command! @one, :console, ['wban', [@two.name, 'forever']]
        @zone.bannings[@two.id.to_s].should eq Time.now.to_i + 100.years.to_i
      end

      it 'should allow permabans if offline bannee has not placed protected items' do
        command! @one, :console, ['wban', [@offline.name, 'forever']]
        eventually do
          @zone.bannings[@offline.id.to_s].should eq Time.now.to_i + 100.years.to_i
        end
      end

      it 'should unban a player' do
        @zone.ban! @two, 99999999
        command! @one, :console, ['wunban', [@two.name]]
        eventually do
          @zone.bannings[@two.id].should be_nil
        end
      end

    end

  end
end
