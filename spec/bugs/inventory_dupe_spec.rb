require 'spec_helper'

describe 'Inventory Duplication on Player Creation' do
  context 'with a zone' do
    before(:each) do
      @zone = ZoneFoundry.create(callbacks: false)
    end

    it 'should not give me the inventory of a previous player' do

      @one, @o_sock = auth_context(@zone)
      @one.inventory.should == {}

      # Set homeboys inventory
      add_inventory(@one, 512, 50)
      disconnect(@o_sock)

      # Log in as player 2
      @two, @t_sock, junk, @t_messages = auth_context(@zone)
      @two.inventory.should == {}
    end
  end
end
