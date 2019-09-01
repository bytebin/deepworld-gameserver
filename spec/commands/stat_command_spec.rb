require 'spec_helper'

describe StatCommand, :with_a_zone_and_player do

  it 'should not allow normal players to set their karma' do
    cmd = command(@player, :stat, ['karma', 20])
    cmd.errors.should_not eq []
  end

  it 'should allow admins to set their karma' do
    @player.admin = true
    command! @player, :stat, ['karma', 20]
    @player.karma.should == 20

    Message.receive_one(@player.socket, only: :stat).data.should eq [['karma', 20]]
  end

end