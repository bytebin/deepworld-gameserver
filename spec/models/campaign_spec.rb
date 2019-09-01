require 'spec_helper'

describe Campaign do
  before(:each) do
    @campaign = CampaignFoundry.create
  end

  it 'should not give the item in a tutorial zone' do
    with_a_zone(static: true, static_type: 'tutorial')
    with_a_player @zone, ref: @campaign.ref

    Message.receive_one(@one.socket, only: :notification).should be_blank
    @one.inventory[@campaign.items.first].should be_nil
  end

  it 'should give me nothing' do
    with_a_zone
    with_a_player @zone, ref: 'other-stuff'

    Message.receive_one(@one.socket, only: :notification).should be_blank
    @one.inventory[@campaign.items.first.to_s].should eq nil

    @one.rewards.should eq({'welcome' => nil})
  end

  it 'should give a welcome item when spawned' do
    with_a_zone
    with_a_player @zone, ref: @campaign.ref

    receive_msg!(@one, :dialog)
    @one.inventory[@campaign.items.first.to_s].should eq 1

    @one.rewards['welcome'].should_not be_blank
    collection(:players).find_one['rewards']['welcome'].should_not be_blank
  end

  it 'should not give me an item twice' do
    with_a_zone
    with_a_player @zone, ref: @campaign.ref

    receive_msg!(@one, :dialog)
    @one.inventory[@campaign.items.first.to_s].should eq 1
    disconnect @one.socket

    @one = auth_context(@zone, id: @one.id)[0]
    receive_msg(@one, :dialog).should be_blank
    @one.inventory[@campaign.items.first.to_s].should eq 1
  end
end
