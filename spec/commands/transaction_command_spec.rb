require 'spec_helper'

describe TransactionCommand do

  before(:each) do
    @zone = ZoneFoundry.create(data_path: :droplets)
    with_2_players @zone, premium: false

    Game.config.stub(:orders).and_return(Hashie::Mash.new(YAML.load(
      %[
        Order of the Moon:
          induction_message: Your financial support of Deepworld has caught the attention of the Order of the Moon! You are an important part of helping Deepworld thrive and we salute you.
          advancement_message: Your continued support of Deepworld pleases the council of the Order of the Moon. We have advanced your position within our ranks to honor your contributions.
          key: moon
          tiers:
            - requirements:
                'crowns_spent': 1000
            - requirements:
                'crowns_spent': 2000
            - requirements:
                'crowns_spent': 4000
            - requirements:
                'crowns_spent': 8000
            - requirements:
                'crowns_spent': 16000
      ]
    )))

  end

  it 'should not allow an invalid transaction item' do
    cmd = command(@one, :transaction, ['small-protectory-thing'])
    cmd.errors.to_s.should =~ /not/
  end

  context 'with a valid item' do

    before(:each) do
      Transaction.stub(:item).and_return(Hashie::Mash.new(
        key: 'small-protector',
        cost: 100,
        inventory: [['mechanical/dish', 2]]
      ))
    end

    it 'should not allow a transaction if a player has too few crowns' do
      @one.crowns = 99
      cmd = command(@one, :transaction, ['small-protector'])
      cmd.errors.to_s.should =~ /enough crowns/
    end

    describe 'calculations' do

      it 'should calculate crowns spent' do
        Transaction.credit @one, 1000, 'test'
        3.times { command! @one, :transaction, ['small-protector'] }
        @one.crowns.should eq 700

        @two.crowns = 1000
        5.times { command! @two, :transaction, ['small-protector'] }

        eventually do
          @one.crowns_spent.should eq 300
        end
      end

    end

    describe 'VIP' do

      before(:each) do
        @one.crowns = 1000
        @one.stub(:v3?).and_return(true)
      end

      it 'should send info about first VIP tier' do
        @one.crowns_spent = 400
        command! @one, :transaction, ['small-protector']
        dialog = receive_msg!(@one, :dialog)
        dialog.data.to_s.should =~ /you are 50% of the way to the first VIP tier/i
        dialog.data.to_s.should =~ /spend 500 more/i
        dialog.data.to_s.should =~ /rank as iron/i
      end

      it 'should send info about subsequent VIP tiers' do
        @one.crowns_spent = 1650
        command! @one, :transaction, ['small-protector']
        dialog = receive_msg!(@one, :dialog)
        dialog.data.to_s.should =~ /you are 75% of the way to the next VIP tier/i
        dialog.data.to_s.should =~ /spend 250 more/i
        dialog.data.to_s.should =~ /rank as brass/i
      end

      it 'should send info about achieveing a VIP tier' do
        @one.crowns_spent = 1950
        command! @one, :transaction, ['small-protector']
        dialog = receive_msg!(@one, :dialog)
        dialog.data.to_s.should =~ /you have achieved a new VIP tier/i
      end

      it 'should not send info VIP tiers if past highest level' do
        @one.crowns_spent = 999999
        command! @one, :transaction, ['small-protector']
        dialog = receive_msg!(@one, :dialog)
        dialog.data.to_s.should_not =~ /VIP tier/i
        dialog.data.to_s.should_not =~ /spend/i
      end

    end

    context 'and enough moneys' do

      before(:each) do
        Game.clear_inventory_changes
        @one.crowns = 105
        command! @one, :transaction, ['small-protector']
        eventually { collection(:transactions).count.should eq 1 }
      end

      it 'should track transactions' do
        transaction = collection(:transactions).find({player_id: @one.id}).first

        transaction.should_not be_blank
        transaction['created_at'].should be_within(1.second).of Time.now
        transaction['item'].should == 'small-protector'
        transaction['amount'].should == -100
      end

      it 'should deduct currency when I buy an item' do
        @one.crowns.should == 5

        collection(:players).find({_id: @one.id}).first['crowns'].should eq 5
        reactor_wait
      end

      it 'should add inventory when I buy an inventory item' do
        dish = Game.item_code('mechanical/dish')

        @one.inv.quantity(dish).should eq 2
        msg = Message.receive_one(@one.socket, only: :inventory)
        msg.data.should == [{ dish.to_s => [2, 'i', -1] }]

        # Tracked changes
        Game.write_inventory_changes
        eventually do
          inv = collection(:inventory_changes).find.first
          inv.should_not be_blank
          inv['p'].should eq @one.id
          inv['z'].should eq @zone.id
          inv['i'].should eq dish
          inv['q'].should eq 2
        end
      end
    end

  end

  it 'should add multiple inventory when I buy an inventory pack' do
    @one.crowns = 500
    command! @one, :transaction, ['exploring-pack']

    @one.inv.quantity(Game.item_code('accessories/jetpack-onyx')).should eq 1
    @one.inv.quantity(Game.item_code('accessories/pocketwatch')).should eq 1
    msg = Message.receive_one(@one.socket, only: :notification)
    msg.data.to_s.should =~ /Onyx Steampack x 1/
  end

  it 'should add wardrobe when I buy a wardrobe pack' do
    @one.crowns = 300
    command! @one, :transaction, ['dance-pack']

    @one.wardrobe.should include(Game.item_code('emotes/dance-swim'))
    msg = receive_msg(@one, :wardrobe)
    msg.data.first.should include(Game.item_code('emotes/dance-swim'))
  end

  it 'should upgrade a player to premium if premium-pack purchased' do
    @one.premium.should eq false

    @one.crowns = 150
    command! @one, :transaction, ['premium-pack']

    msg = receive_msg!(@one, :dialog)
    msg.data.to_s.should =~ /You are now a premium player/

    @one.premium.should eq true
  end

  it 'should prohibit me from purchasing based on current inventory' do
    item = stub_item('thingy')
    prohibited_item = stub_item('prohibited')
    Transaction.stub(:item).and_return(Hashie::Mash.new(
      key: 'thingy',
      cost: 100,
      inventory: ['thingy', 2],
      prohibit_inventory: ['prohibited']
    ))

    @one.crowns = 100
    add_inventory @one, prohibited_item.code, 1
    command(@one, :transaction, ['thingy']).errors.to_s.should =~ /cannot/
    receive_msg!(@one, :notification).data.to_s.should =~ /cannot/
  end

  describe 'private worlds' do

    before(:each) do
      Transaction.stub(:item).and_return Hashie::Mash.new({ 'key' => 'private-world', 'zone' => 'type_1', 'cost' => 500 })
      ConfigurationFoundry.create key: 'world_version', data: 9999
      @one.crowns = 500
    end

    def purchase_and_verify_error
      command! @one, :transaction, ['private-world']
      msg = receive_msg!(@one, :dialog)
      msg.data[1].to_s.should =~ /started generating/
      collection(:alerts).count.should eq 1
    end

    def find_zone(zone_id)
      collection(:zones).find({ '_id' => zone_id }).to_a.first
    end

    it 'should provision a private world' do
      zone1 = ZoneFoundry.create(active: false, gen_type: 'type_1', version: 9999)

      command! @one, :transaction, ['private-world']
      msg = receive_msg!(@one, :dialog)
      msg.data[1].to_s.should =~ /Your private world/
      collection(:zones).find.first

      find_zone(zone1.id)['active'].should be_true
      find_zone(zone1.id)['private'].should be_true
      find_zone(zone1.id)['owners'].should eq [@one.id]
    end

    it 'should not provision an active private world' do
      zone1 = ZoneFoundry.create(active: true, gen_type: 'type_1', version: 9999)
      purchase_and_verify_error
    end

    it 'should not provision a private world with play time' do
      zone1 = ZoneFoundry.create(active: false, gen_type: 'type_1', version: 9999, active_duration: 600)
      purchase_and_verify_error
    end

    it 'should not provision a private world with the wrong type' do
      zone1 = ZoneFoundry.create(active: false, gen_type: 'type_2', version: 9999)
      purchase_and_verify_error
    end

    it 'should not provision more than one private world' do
      zone1 = ZoneFoundry.create(active: false, gen_type: 'type_1', version: 9999)
      zone2 = ZoneFoundry.create(active: false, gen_type: 'type_1', version: 9999)

      find_zone(zone1.id)['active'].should be_false
      find_zone(zone1.id)['private'].should be_false
      find_zone(zone1.id)['owners'].should be_nil
    end

    it 'should send me to my new private world if I request' do
      zone0 = ZoneFoundry.create(active: true, owners: [@one.id])
      zone1 = ZoneFoundry.create(active: false, gen_type: 'type_1', version: 9999)

      command! @one, :transaction, ['private-world']
      msg = receive_msg!(@one, :dialog)
      command! @one, :dialog, [msg.data[0], []]
      msg = receive_msg!(@one, :kick)
    end

  end

end
