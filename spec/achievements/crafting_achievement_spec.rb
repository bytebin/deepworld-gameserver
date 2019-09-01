require 'spec_helper'

describe Achievements::CraftingAchievement do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)

    # Give him wood
    add_inventory(@one, 'building/wood', 9999)

    @zone = Game.zones[@zone.id]

    cfg = Game.config.achievements['Craftsman']
    cfg.quantity = 3
  end

  it 'should award me with a craftsman achievement if I craft enough items' do
    ['back/wood', 'building/wood-board', 'building/post-wood'].each do |item_name|
      10.times { CraftCommand.new([Game.item_code(item_name)], @one.connection).execute! }
    end

    msgs = Message.receive_many(@o_sock, only: :achievement)
    msgs.size.should == 1
    msgs.first.should_not be_blank
    msgs.first.data.first.should == ['Craftsman', 2000]
  end

  it 'should not award me if I craft too few item types' do
    ['back/wood', 'building/wood-board'].each do |item_name|
      50.times { CraftCommand.new([Game.item_code(item_name)], @one.connection).execute! }
    end
    Message.receive_many(@o_sock, only: :achievement).should be_blank
  end

end
