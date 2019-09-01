require 'spec_helper'

describe Players::Invite do

  before(:each) do
    @player = double('Player')
  end

  it 'should describe zero upgrade progress if no invites have been responded' do
    @player.stub(:invite_responses).and_return([])
    Players::Invite.upgrade_progress(@player).should be_nil
  end

  it 'should describe upgrade progress if one invite has been responded' do
    @player.stub(:invite_responses).and_return(['aaa'])
    Players::Invite.upgrade_progress(@player).should eq ['arctic', 1]
  end

  it 'should describe upgrade progress if three invites have been responded' do
    @player.stub(:invite_responses).and_return(['aaa', 'bbb', 'ccc'])
    Players::Invite.upgrade_progress(@player).should eq ['arctic', 0]
  end

  it 'should describe zero upgrade progress if invite responses go past available upgrades' do
    @player.stub(:invite_responses).and_return(['aaa'] * 100)
    Players::Invite.upgrade_progress(@player).should be_nil
  end

end