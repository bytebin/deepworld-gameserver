require 'spec_helper'

describe ZoneKernel::Light do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twohundo, size: Vector2.new(200,200))
    @dummy, @d_sock = auth_context(@zone)

    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
  end

  it 'should calculate sunlight on zone spinup' do
    @zone.light.sunlight[0..12].should == [2, 2, 2, 3, 3, 3, 3, 6, 6, 6, 6, 6, 3]

    Game.step!(true)
  end

  describe 'changes' do

    before(:each) do
      (0..4).each do |y|
        (0..1).each do |x|
          @zone.update_block nil, x, y, FRONT, y == 4 ? Game.item_code('ground/earth') : 0, 0
        end
      end
      Message.receive_many(@o_sock)
    end

    it 'should block light if a whole block is placed' do
      @zone.update_block nil, 0, 2, FRONT, Game.item_code('ground/earth')

      msg = Message.receive_one(@o_sock, only: :light)
      msg[:x].should eq [0]
      msg[:value].should eq [[2]]
    end

    it 'should unblock light if I remove a whole block' do
      @zone.update_block nil, 0, 2, FRONT, Game.item_code('ground/earth')
      Message.receive_one(@o_sock, only: :light)
      @zone.update_block nil, 0, 2, FRONT, 0

      msg = Message.receive_one(@o_sock, only: :light)
      msg[:x].should eq [0]
      msg[:value].should eq [[4]]
    end

    it 'should block light if a shelter block is placed' do
      @zone.update_block nil, 0, 2, FRONT, Game.item_code('building/roof-edge')

      msg = Message.receive_one(@o_sock, only: :light)
      msg[:x].should eq [0]
      msg[:value].should eq [[2]]
    end

    it 'should not block light if a non-physical block is placed' do
      @zone.update_block nil, 0, 2, FRONT, Game.item_code('lighting/lantern')

      msg = Message.receive_one(@o_sock, only: :light).should be_blank
    end
  end
end