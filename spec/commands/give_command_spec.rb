require 'spec_helper'

describe GiveCommand do
  context 'with an admin' do
    before(:each) do
      @zone = ZoneFoundry.create
      @one, @o_sock = auth_context(@zone, admin: true, inventory: { '600' => [ 1, 'h', 1 ] })
    end

    it 'should give me more inventory when I send a give command' do
      Message.new(:give, [@one.name, 600, 5]).send(@o_sock)
      msg = Message.receive_one(@o_sock, only: :inventory)
      msg.should be_message(:inventory)

      @one.inv.quantity(600).should eq 6
    end

    it 'should give another player inventory when I send a give command' do
      @two, @t_sock = auth_context(@zone, inventory: { '600' => [ 1, 'h', 1 ] })
      Message.new(:give, [@two.name, 600, 5]).send(@o_sock)

      msg = Message.receive_one(@t_sock, only: :inventory)
      msg.should be_message(:inventory)

      @one.inv.quantity(600).should eq 1
      @two.inv.quantity(600).should eq 6
    end
  end

  context 'without admin', :with_a_zone_and_2_players do
    before(:each) do
      add_inventory(@one, 600, 10)
    end

    it 'should deduct inventory that I give' do
      command! @one, :give, [@two.name, 600, 5]
      msg = Message.receive_one(@two.socket, only: [:inventory]).data.first.should eq({ '600' => [5, 'i', -1] })
      @one.inv.quantity(600).should eq 5
      @two.inv.quantity(600).should eq 5
    end

    it 'should not allow me to give more than I have' do
      command(@one, :give, [@two.name, 600, 15]).errors.should_not eq []
      @one.inv.quantity(600).should eq 10
      @two.inv.quantity(600).should eq 0
    end

    it 'should not allow me to give invalid item' do
      command(@one, :give, [@two.name, 1234567, 'tons']).errors.should_not eq []
    end

    it 'should not allow me to give to invalid player' do
      command(@one, :give, ['floopdedoop', 600, 5]).errors.to_s.should =~ /floopdedoop/
    end

    it 'should not allow me to give invalid amount' do
      command(@one, :give, [@two.name, 600, 'tons']).errors.to_s.should =~ /invalid/i
    end

    it 'should not allow non-admins to give to themselves' do
      command(@one, :give, [@one.name, 600, 5]).errors.to_s.should =~ /self/
    end

    it 'should track inventory changes' do
      Game.clear_inventory_changes
      command! @one, :give, [@two.name, 600, 5]
      Game.write_inventory_changes

      eventually do
        inv = collection(:inventory_changes).find.first
        inv.should_not be_blank
        inv['p'].should eq @one.id
        inv['z'].should eq @zone.id
        inv['i'].should eq 600
        inv['q'].should eq -5
        inv['l'].should be_blank
        inv['op'].should eq @two.id
        inv['oi'].should be_blank
        inv['oq'].should be_blank
      end

    end
  end
end
