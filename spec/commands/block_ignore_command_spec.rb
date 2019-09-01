require 'spec_helper'

describe BlocksIgnoreCommand do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twohundo, size: Vector2.new(200,200))

    @one, @o_sock = auth_context(@zone, {inventory: { '600' => [ 2, 'i', 1 ] }} )
    @two, @t_sock = auth_context(@zone)
    @one.admin = @one.admin_enabled = true # Ignore mining validations

    Game.play
  end

  def pay_attention_to(socket, *indexes)
    Message.new(:blocks_request, [indexes]).send(socket)
  end

  it "should not send me updates for in-active blocks" do
    Message.new(:block_place, [25, 45, 1, 600, 0]).send(@o_sock)
    msg = Message.receive_one(@t_sock, only: :block_change)

    msg.should be_nil
  end

  it "should send me updates for active blocks" do
    pay_attention_to(@t_sock, 21)
    Message.new(:block_place, [25, 45, 1, 600, 0]).send(@o_sock)
    msg = Message.receive_one(@t_sock, only: :block_change)

    msg.data.should eq [[25, 45, 1, 1, 600, 0]]
  end

  it "should not send me updates for ignored blocks" do
    pay_attention_to(@t_sock, 21)

    Message.new(:blocks_ignore, [[21]]).send(@t_sock)
    Message.new(:block_place, [25, 45, 1, 600, 0]).send(@o_sock)
    msg = Message.receive_one(@t_sock, only: :block_change)

    msg.should be_nil
  end
end
