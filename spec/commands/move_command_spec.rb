require 'spec_helper'

describe 'Move' do
  before(:each) do
    @timeout = 0.25
    @zone = ZoneFoundry.create(spawn: false)
    @zone.spawner = nil

    @mover, @m_sock = auth_context(@zone)
    @one, @o_sock = auth_context(@zone)
    @two, @t_sock = auth_context(@zone)

    Game.play

    @zone = Game.zones[@zone.id]
  end

  it 'should broadcast my new location to other players' do
    @mover.position = Vector2[5.5, 5.5]
    # Clear out initial messages
    msgs = [@m_sock, @o_sock, @t_sock].map {|socket| Message.receive_many(socket, only: :entity_position) }

    movement = [5 * Entity::POS_MULTIPLIER.to_i, 5 * Entity::POS_MULTIPLIER.to_i, 2, 2, 1, 0, 0, 1]
    Message.new(:move, movement).send(@m_sock)

    msgs = [@o_sock, @t_sock].map {|socket| Message.receive_one(socket, only: :entity_position) }
    msgs.should be_messages [:entity_position, :entity_position]
    msgs.map(&:data).should include [[@mover.entity_id] + movement]
  end

  it 'should not allow a movement outside of the zone' do
    @mover.position = Vector2[4.9, 4.9]
    request = Message.new(:move, [-100, 5, 2, 2, 1, 0, 0, 1])
    request.send(@m_sock)

    msg = Message.receive_one(@m_sock, timeout: 0.5, only: :player_position)
    msg.should_not be_nil
    msg[:x].should eq @mover.position.x
    msg[:y].should eq @mover.position.y
  end

  pending 'it should not allow me to move too far (position)' do

  end

  pending 'it should not allow me to move too fast (velocity)' do

  end

  it 'should track where a zone has been explored' do
    @zone.chunks_explored.uniq.should == [false]
    @one.position = Vector2[0, 0]
    MoveCommand.new([0, 0, 0, 0, 0, 0, 0, 0], @one.connection).execute!
    @zone.chunks_explored.should == [true, false, false, false]
    @zone.chunks_explored_count.should == 1

    @one.position = Vector2[10, 0]
    MoveCommand.new([10 * Entity::POS_MULTIPLIER, 0, 0, 0, 0, 0, 0, 0], @one.connection).execute!
    @zone.chunks_explored.should == [true, false, false, false]
    @zone.chunks_explored_count.should == 1

    @one.position = Vector2[42, 15]
    MoveCommand.new([42 * Entity::POS_MULTIPLIER, 15 * Entity::POS_MULTIPLIER, 0, 0, 0, 0, 0, 0], @one.connection).execute!
    @zone.chunks_explored.should == [true, false, true, false]
    @zone.chunks_explored_count.should == 2
  end
end