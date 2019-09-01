require 'spec_helper'

describe Players::Orders do

  before(:each) do
    with_a_zone
    with_2_players
    @one.xp = -9999

    Game.config.stub(:orders).and_return(Hashie::Mash.new({
      'all' => {
        'peer_induction_message' => 'has been inducted into the',
        'peer_advancement_message' => 'has advanced within the'
      },
      'Order of the Test' => {
        'key' => 'test',
        'induction_message' => 'Congrats! You test well.',
        'advancement_message' => 'Awesome! You are testing even better now.',
        'tiers' => [
          { 'requirements' => { 'req1' => 100, 'req2/stuff' => 5, 'req3' => 50 }},
          { 'requirements' => { 'req1' => 200, 'req2/stuff' => 10, 'req3' => 100 }}
        ]
      }
    }))
  end

  def meet_order_requirements(tier, override = {})
    amts = [{ req1: 105, req2: 5, req3: 105}, { req1: 300, req2: 20, req3: 300 }][tier - 1].merge(override)

    @one.stub(:req1).and_return(amts[:req1])
    @one.stub(:req2).and_return({ 'stuff' => amts[:req2] })
    @one.stub(:req3).and_return(amts[:req3])

    @one.check_orders
  end

  it 'should induct a player into an order if they meet requirements' do
    meet_order_requirements 1

    @one.orders.should eq({ 'test' => 1 })
    receive_msg!(@one, :event).data.to_s.should =~ /icon/i
    receive_msg!(@one, :dialog).data.to_s.should =~ /Congrats/
  end

  it 'should induct a player directly into a higher tier of an order if they meet requirements' do
    meet_order_requirements 2

    @one.orders.should eq({ 'test' => 2 })
    receive_msg!(@one, :dialog).data.to_s.should =~ /Congrats/
  end

  it 'should not induct a player into an order if they do not meet generic requirements' do
    meet_order_requirements 1, req2: 3

    @one.orders.should be_blank
  end

  it 'should not induct a player into an order if they do not meet order requirements' do
    meet_order_requirements 1, req2: 6, req3: 30

    @one.orders.should be_blank
  end

  it 'should not re-induct a player into an order' do
    @one.orders = { 'test' => 1 }
    meet_order_requirements 1

    @one.orders.should eq({ 'test' => 1 })
  end

  it 'should advance a player within an order' do
    @one.orders = { 'test' => 1 }
    meet_order_requirements 2

    @one.orders.should eq({ 'test' => 2 })
    receive_msg!(@one, :dialog).data.to_s.should =~ /Awesome/
  end

  it 'should notify peers of order information' do
    @one.name = 'bubble'
    meet_order_requirements 1
    @one.check_orders

    receive_msg!(@two, :notification).data.first.should eq 'bubble has been inducted into the Order of the Test.'
  end

  it 'should not notify peers of private order information' do
    Game.config.orders['Order of the Test'].hidden = true

    @one.name = 'bubble'
    meet_order_requirements 1
    @one.check_orders

    receive_msg(@two, :notification).should be_blank
  end

  def membership_doc
    doc = collection(:order_membership).find.first
    doc.delete '_id'
    doc
  end

  it 'should create an order membership doc' do
    meet_order_requirements 1
    eventually do
      membership_doc.should eq({ 'player_id' => @one.id, 'order' => 'test', 'tier' => 1 })
    end
  end

  it 'should update an order membership doc' do
    meet_order_requirements 1
    meet_order_requirements 2
    eventually do
      membership_doc.should eq({ 'player_id' => @one.id, 'order' => 'test', 'tier' => 2 })
      collection(:order_membership).count.should eq 1
    end
  end

end