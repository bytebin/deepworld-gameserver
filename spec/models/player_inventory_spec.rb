require 'spec_helper'

describe Player do
  describe 'With a zone and player' do
    before(:each) do
      @zone = with_a_zone
    end

    it 'should convert my inventory to the new version' do
      with_a_player(@zone, inventory: {'1026' => [2, 'h', 0], '1025' => [3, 'a', 1] })

      @one.inventory.should == { '1026' => 2, '1025' => 3 }
      acc = [nil] * PlayerInventory::ACCESSORY_SLOTS
      acc[1] = 1025
      locations = {
        'a' => acc,
        'h' => [1026, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      }
      @one.inventory_locations.should eq locations
    end

    it 'should persist inventory in the new format' do
      with_a_player(@zone, inventory: {'1026' => [2, 'h', 0], '1025' => [3, 'a', 1] })

      eventually {
        player = collection(:players).find(name: @one.name).to_a.first
        player['inventory'].should == { '1026' => 2, '1025' => 3 }
        locations = {
          'a' => [nil, 1025, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
          'h' => [1026, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        }
      }
    end

    it "should remove invalid items from inventory" do
      with_a_player(@zone, inventory: { '1025' => 5, '1026' => 8, '23' => 50 }, inventory_locations: {'h' => [1025,1026,23,nil,nil,nil,nil,nil,nil,nil]})
      @one.inv.quantity(1025).should eq 5
      @one.inv.quantity(1026).should eq 8
      @one.inv.quantity(23).should eq 0
      @one.inv.location_of(1025).should eq ['h', 0]
      @one.inv.location_of(1026).should eq ['h', 1]
      @one.inv.location_of(23).should eq ['i', -1]
    end


    describe 'with a player' do
      before(:each) do
        with_a_player(@zone, inventory: {'1026' => 1}, inventory_positions: {'a' => [nil] * 12, 'h' => [nil] * 10})
      end

      it 'should persist added inventory' do
        @one.inv.add(512, 99)

        @one.inv.save!

        eventually {
          player = collection(:players).find(name: @one.name).to_a.first
          player['inventory'].should == {'1026' => 1, '512' => 99}
        }
      end

      it 'should persist removed inventory' do
        @one.inv.remove(1026, 1)

        @one.inv.save!

        eventually {
          player = collection(:players).find(name: @one.name).to_a.first
          player['inventory'].should == {'1026' => 0}
        }
      end

      it 'should persist added and removed inventory' do
        @one.inv.remove(1026, 1)
        @one.inv.add(512, 22)

        @one.inv.save!

        eventually {
          player = collection(:players).find(name: @one.name).to_a.first
          player['inventory'].should == {'1026' => 0, '512' => 22}
        }
      end

      it 'should present a player a message for a single item' do
        @one.inv.add_with_message(Game.item(1030), count = 2, message = "Here's this:")

        msg = Message.receive_one(@one.socket, only: :notification)
        msg.should_not be_blank

        msg.data.first['sections'].should eq [{"title"=>"Here's this:", "list"=>[{"item"=>"tools/gun-steam", "text"=>"Steam Cannon x 2"}]}]
      end
    end
  end
end
