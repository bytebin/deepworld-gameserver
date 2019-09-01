require 'spec_helper'

describe Scenarios::TutorialGiftHomeWorld do

  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twentyempty, scenario: 'TutorialGiftHomeWorld')
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    Game.play
  end

  describe 'reaching end' do

    def reach_end!
      @zone.player_event @one, :waypoint, ['end', nil]
    end

    before(:each) do
      reach_end!
    end

    it 'should notify me about crown purchases when I hit the end' do
      msg = receive_msg!(@one, :dialog)
      msg.data.to_s.should =~ /Received 200 crowns/
    end

    it 'should send me shop hints after I close the notification dialog' do
      msg = receive_msg!(@one, :dialog)
      dialog_id = msg.data[0]
      command! @one, :dialog, [dialog_id, []]

      msg = receive_msg!(@one, :event)
      msg.data.to_s.should =~ /uiHints/
    end

    it 'should give me crowns the first time I hit the end' do
      eventually do
        @one.crowns.should eq 200
      end
    end

    it 'should not give me crowns after the first time I hit the end' do
      3.times { reach_end! }
      Transaction.credit(@one, 1, 'testing')
      eventually do
        @one.crowns.should eq 201
      end
    end

    it 'should let me buy a home world and send me there' do
      @home_world = ZoneFoundry.create(scenario: 'HomeWorld', active: false)
      @home_world_2 = ZoneFoundry.create(scenario: 'HomeWorld', active: false)

      command! @one, :transaction, ['home-world']

      eventually do
        @one.zone_id.should eq @home_world.id

        zone = collection(:zones).find({ '_id' => @home_world.id }).first
        zone['active'].should eq true
        zone['locked'].should eq true
        zone['private'].should eq true
        zone['owners'].should eq [@one.id]

        other_zone = collection(:zones).find({ '_id' => @home_world_2.id }).first
        other_zone['active'].should eq false
        other_zone['owners'].should be_blank
      end
    end

    it 'should not let me buy anything but a home world' do
      @one.crowns = 1000
      command(@one, :transaction, ['power-pack']).should_not be_valid
      receive_msg!(@one, :notification).data.to_s.should =~ /in the tutorial/
    end

  end

  # it 'should not let people chat' do
  #   command @one, :chat, [nil, 'Hellooooo world']
  #   msg = receive_msg!(@one, :notification)
  #   msg.data.to_s.should =~ /is disabled/
  # end

end
