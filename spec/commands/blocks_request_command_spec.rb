require 'spec_helper'

describe BlocksRequestCommand do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twohundo, size: Vector2.new(200,200))

    @one, @o_sock = auth_context(@zone, {inventory: { '600' => [ 2, 'i', 1 ], '890' => [2, 'i', 1] }} )

    @zone = Game.zones[@zone.id]
    Game.play
  end

  it 'should deliver the origin chunk' do
    command! @one, :blocks_request, [[0]]
    blocks = receive_msg(@one, :blocks)

    blocks[0][0..3].should eq [0, 0, 20, 20]
  end

  it 'should deliver correct chunks for blocks' do
    command! @one, :blocks_request, [[1, 12]]
    blocks = receive_msg(@one, :blocks)

    blocks[0][0..3].should eq [20, 0, 20, 20]
    blocks[1][0..3].should eq [40, 20, 20, 20]
  end
end