require 'spec_helper'

describe RedeemCommand do
   before(:each) do
    @zone = ZoneFoundry.create
    @player, @socket = auth_context(@zone, inventory: {})
    Game.play
  end

  def redeem_command!(code, console_command, player)
    if console_command
      command! player, :console, ['redeem', [code]]
    else
      command! player, :redeem, [code]
    end
  end

  def redeem_command(code, console_command, player)
    if console_command
      command player, :console, ['redeem', [code]]
    else
      command player, :redeem, [code]
    end
  end


  # Test via normal and console versions
  [false, true].each do |console|
    context "via a #{console ? 'console' : 'normal'} command" do
      it 'should mark that Ive redeemed a code' do
        redemption = RedemptionCodeFoundry.create(inventory: { '1024' => 3 })

        redeem_command!(redemption.code, console, @player)

        eventually do
          redemption = RedemptionCodeFoundry.reload(redemption)
          redemption.redeemers.should include(@player.id)
          redemption.redemptions.should eq 1
        end
      end

      it 'should give me items' do
        Game.clear_inventory_changes

        redemption = RedemptionCodeFoundry.create(inventory: { '1026' => 3 })

        redeem_command!(redemption.code, console, @player)

        msg = Message.receive_one(@socket, only: :inventory)
        msg[:inventory_hash].should == {"1026" => [3, "i", -1]}

        @player.inv.quantity(1026).should eq 3

        # Tracked changes
        Game.write_inventory_changes
        eventually do
          inv = collection(:inventory_changes).find.first
          inv.should_not be_blank
          inv['p'].should eq @player.id
          inv['z'].should eq @zone.id
          inv['i'].should eq 1026
          inv['q'].should eq 3
          inv['l'].should be_blank
          inv['op'].should be_blank
          inv['oi'].should be_blank
          inv['oq'].should be_blank
        end
      end

      it 'should change my appearance' do
        redemption = RedemptionCodeFoundry.create(appearance:  { 'hg' => 'avatar/helmet', 'hg*' => 'ffffff' })

        redeem_command!(redemption.code, console, @player)

        msg = Message.receive_one(@socket, only: :entity_status)
        msg[:details][0]['hg'].should eq 'avatar/helmet'
        msg[:details][0]['hg*'].should eq 'ffffff'

        @player.appearance['hg'].should eq 'avatar/helmet'
        @player.appearance['hg*'].should eq 'ffffff'
      end

      it 'should give me wardrobe items' do
        redemption = RedemptionCodeFoundry.create(wardrobe: ['1333'])
        redeem_command!(redemption.code, console, @player)

        eventually { @player.wardrobe.should include("1333")}
        msg = Message.receive_one(@socket, only: :wardrobe)
        msg[:wardrobe_ids].should eq ["1333"]
      end

      it 'should give me crowns' do
        redemption = RedemptionCodeFoundry.create(crowns: 500)

        redeem_command!(redemption.code, console, @player)

        msg = Message.receive_one(@socket, only: :stat)
        msg[:key].should == ['crowns']
        msg[:value].should == [500]

        @player.crowns.should eq 500
      end

      it 'should notify me that i got stuff' do
        redemption = RedemptionCodeFoundry.create(wardrobe: ['1333'])
        redeem_command!(redemption.code, console, @player)

        msg = Message.receive_one(@socket, only: :notification)
        msg[:status].should eq 12
      end

      it 'should not let me redeem a code twice' do
        redemption = RedemptionCodeFoundry.create(inventory: { '1024' => 3 }, limit: 2)
        redeem_command!(redemption.code, console, @player)

        eventually { @player.inv.quantity(1024).should eq 3 }
        Message.receive_one(@socket, only: :notification)[:status].should eq 12

        cmd = RedeemCommand.new([redemption.code], @player.connection)
        cmd.execute!

        msg = Message.receive_one(@socket, only: :notification)
        msg[:message].should eq "Redemption code has been used"

        @player.inv.quantity(1024).should eq 3
      end

      it 'should let different players redeem a multiredemption code' do
        player2, socket2 = auth_context(@zone, inventory: {})

        redemption = RedemptionCodeFoundry.create(inventory: { '1024' => 3 }, limit: 2)

        [@player, player2].each do |p|
          redeem_command!(redemption.code, console, p)

          eventually { p.inv.quantity(1024).should eq 3 }
        end

        eventually do
          redemption = RedemptionCodeFoundry.reload(redemption)
          redemption.redeemers.should =~ [@player.id, player2.id]
          redemption.redemptions.should eq 2
        end
      end

      it 'should send notification when a code is not found' do
        redemption = RedemptionCodeFoundry.create(inventory: { '1024' => 3 })
        redeem_command!('bloop', console, @player)

        msg = Message.receive_one(@socket, only: :notification)
        msg[:message].should eq "Redemption code not found"

        @player.inv.quantity(1024).should eq 0
      end

      it 'should prevent free players from cashing in on premium redemption codes' do
        @player.premium = false
        redemption = RedemptionCodeFoundry.create(inventory: { '1024' => 3 }, premium: true)
        redeem_command!(redemption.code, console, @player)

        msg = Message.receive_one(@socket, only: :notification)

        msg[:message].should =~ /premium/

        @player.inv.quantity(1024).should eq 0
      end

      it 'should allow usage of an access code for premium status' do
        @player.premium = false
        access_code = AccessCodeFoundry.create

        redeem_command!(access_code.code, console, @player)

        msg = Message.receive_one(@socket, only: :stat)
        msg[:key].should eq ['premium']
        msg[:value].should eq [true]

        @player.premium.should be_true
        collection(:access_code).find_one['redemptions'].should eq 1
      end

      it 'should not allow double usage of an access code' do
        @player.premium = false
        access_code = AccessCodeFoundry.create(redemptions: 1)

        redeem_command!(access_code.code, console, @player)

        msg = Message.receive_one(@socket, only: :notification)
        msg[:message].should eq "Access code has been used"
        @player.premium.should be_false

        collection(:access_code).find_one['redemptions'].should eq 1
      end

      it 'should fail if the player is already premium' do
        @player.premium = true
        access_code = AccessCodeFoundry.create

        redeem_command(access_code.code, console, @player)

        msg = Message.receive_one(@socket, only: :notification)
        msg[:message].should eq "You are already a premium player"

        collection(:access_code).find_one['redemptions'].should eq 0
      end

      it 'should fail if it cannot find an access code' do
        @player.premium = false

        redeem_command!('ajunkypants', console, @player)

        msg = Message.receive_one(@socket, only: [:notification, :stat])
        msg[:message].should eq "Access code not found"
      end

      it 'should make you the owner if youre the first to enter a zone' do
        @zone = ZoneFoundry.create(private: true)
        redeem_command!(@zone.entry_code, console, @player)

        msg = Message.receive_one(@socket, only: [:kick])
        msg.should be_message(:kick)
        ZoneFoundry.reload(@zone).owners.should include(@player.id)
      end

      it 'should not let you enter an unknown zone' do
        redeem_command!('zjunants', console, @player)

        msg = Message.receive_one(@socket, only: [:notification])
        msg[:message].should eq "Can't find a zone for that code."
      end
    end
  end
end
