require 'spec_helper'

describe Achievements::UndertakerAchievement do
  before(:each) do
    @skeleton = 970
    @gravestone = 960

    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    add_inventory(@one, @gravestone, 2)
    @one.play_time = 333
    @one.admin = @one.admin_enabled = true # Ignore mining validations

    @zone = Game.zones[@zone.id]
  end

  it 'should award me with an undertaker award if I place tombstones above properly buried skeletons' do
    Game.config.achievements['Undertaker'].quantity = 2

    @zone.update_block nil, 5, 5, BASE, 0
    @zone.update_block nil, 5, 5, BACK, 0
    @zone.update_block nil, 5, 5, FRONT, 0

    @zone.update_block nil, 5, 6, BASE, 2
    @zone.update_block nil, 6, 6, BASE, 2
    @zone.update_block nil, 4, 6, FRONT, 512
    @zone.update_block nil, 5, 6, FRONT, @skeleton
    @zone.update_block nil, 6, 6, FRONT, 0
    @zone.update_block nil, 7, 6, FRONT, 512

    @zone.update_block nil, 5, 7, FRONT, 512
    @zone.update_block nil, 6, 7, FRONT, 512

    BlockPlaceCommand.new([5, 5, FRONT, @gravestone, 0], @one.connection).execute!
    @one.progress['undertakings'].should == 1
    @one.has_achieved?('Undertaker').should be_false
    @one.achievements['Undertaker'].should be_blank
    Message.receive_one(@o_sock, only: :achievement).should be_blank

    # One more time

    @zone.update_block nil, 5, 5, FRONT, 0
    @zone.update_block nil, 5, 6, FRONT, @skeleton
    @zone.update_block nil, 6, 6, FRONT, 0
    BlockPlaceCommand.new([5, 5, FRONT, @gravestone, 0], @one.connection).execute!
    @one.progress['undertakings'].should == 2
    @one.has_achieved?('Undertaker').should be_true
    @one.achievements['Undertaker'][:play_time].should == 333

    msg = Message.receive_one(@o_sock, only: :achievement)
    msg.should_not be_blank
    msg.data.first.should == ['Undertaker', 2000]
  end
end
