require 'spec_helper'

describe Transaction do

  before(:each) do
    @zone = ZoneFoundry.create
    @one = PlayerFoundry.create(zone_id: @zone.id, premium: false)
  end

  pending 'should apply pending referral transactions' do
    @one.update premium: true

    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'referred', source_identifier: 'jimmi', pending: true)
    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'referral', source_identifier: 'amanda', pending: true)
    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'referral', source_identifier: 'steven', pending: true)

    @one, @socket = login(@zone, @one.id)

    msg = receive_msg!(@one, :dialog)
    msg.data.to_s.should =~ /Referral Bonus/
    msg.data.to_s.should =~ /50 crown bonus from jimmi/

    msg = msgs.last[:message]["sections"].first
    msg["title"].should eq "Referral Bonus:"

    list = msg["list"].first
    list["image"].should eq "shop/crowns"
    list["text"].should match /100 crown referral bonus/
    list["text"].should match /amanda/
    list["text"].should match /steven/

    #should == {"sections"=>[{"title"=>"Referral Bonus:", "list"=>[{"image"=>"shop/crowns", "text"=>"100 crown referral bonus for amanda and steven!"}]}]}
    msgs.last[:status].should eq 12

    @one.crowns.should eq 150

    trans = collection(:transactions).find.to_a
    trans[0]['pending'].should be_false
    trans[0]['player_id'].should eq @one.id
    trans[0]['amount'].should eq 50
    trans[1]['pending'].should be_false
    trans[2]['pending'].should be_false
  end

  it 'should not apply pending transactions for free players' do
    @one = PlayerFoundry.create(zone_id: @zone.id, premium: false)

    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'referred', source_identifier: 'jimmi', pending: true)
    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'referral', source_identifier: 'amanda', pending: true)

    @one, @socket = login(@zone, @one.id)

    msgs = Message.receive_many(@socket, only: :notification)

    msgs.count.should eq 0

    trans = collection(:transactions).find.to_a
    trans[0]['pending'].should be_true
    trans[1]['pending'].should be_true
  end

  it 'should remove pending flag' do
    @one.update premium: true

    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'referred', source_identifier: 'steven', pending: true)

    @one, @socket = login(@zone, @one.id)

    msg = receive_msg!(@one, :dialog)
    msg.data.to_s.should =~ /Referral Bonus/
    msg.data.to_s.should =~ /50 crown bonus from steven/

    @one.crowns.should eq 50
    collection(:transactions).count.should == 1
    trans = collection(:transactions).find_one
    trans['pending'].should eq false
  end

  it 'should apply premium status' do
    collection(:transactions).insert(player_id: @one.id, amount: 50, premium: true, source: 'web', pending: true)
    @one, @socket = login(@zone, @one.id)
    @one.should be_premium

    msg = receive_msg!(@one, :dialog)
    msg.data.to_s.should =~ /premium/
    msg.data.to_s.should =~ /50 crowns/

    stats = receive_many(@one, :stat)
    stats.map(&:data).should eq [[['crowns', 50]], [['premium', true]]]
  end

  it 'should give a player crowns for offer completion' do
    collection(:transactions).insert(player_id: @one.id, amount: 50, source: 'offer', source_identifier: 'blooopdidybloopdoop', pending: true)
    @one, @socket = login(@zone, @one.id)

    msg = receive_msg!(@one, :dialog)
    msg.data.to_s.should =~ /50 crowns/
    @one.crowns.should eq 50
  end

  it 'should create referral transactions when a player converts to premium' do
    @two = PlayerFoundry.create(zone_id: @zone.id, premium: false)
    @one.update referrer: @two.id

    collection(:transactions).insert(player_id: @one.id, amount: 50, premium: true, source: 'web', pending: true)
    @one, @socket = login(@zone, @one.id)
    @one.should be_premium

    referrer = collection(:transactions).find(source: 'referred').to_a
    referral = collection(:transactions).find(source: 'referral').to_a

    referrer.count.should eq 1
    referrer.first['player_id'].should eq @one.id
    referrer.first['amount'].should eq 50
    referrer.first['pending'].should eq true

    referral.count.should eq 1
    referral.first['player_id'].should eq @two.id
    referral.first['amount'].should eq 50
    referral.first['pending'].should eq true
  end

  it 'should not apply premium status without a premium flag in the transaction' do
    collection(:transactions).insert(player_id: @one.id, amount: 50, premium: false, source: 'web', pending: true)
    @one, @socket = login(@zone, @one.id)
    Transaction.apply_pending @one
    @one.should_not be_premium
  end
end