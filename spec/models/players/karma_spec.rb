require 'spec_helper'
include BlockHelpers

describe :karma do
  before(:each) do
    @brass = 650
    @dirt = 512
    @zone = ZoneFoundry.create(data_path: :twentyempty)
    with_2_players(@zone)

    @zone = Game.zones[@zone.id]
    extend_player_reach @one, @two
  end

  def grief(griefer, griefee, quantity, item = nil)
    item ||= stub_item('stone', { 'karma' => -1 }).code
    add_inventory(griefee, item, quantity) if griefee
    quantity.times do
      # Place block
      if griefee
        command! griefee, :block_place, [5, 5, FRONT, item, 0]
      else
        @zone.update_block nil, 5, 5, FRONT, item
      end

      # Mine block
      command! griefer, :block_mine, [5, 5, FRONT, item, 0]
    end
  end

  it 'should describe karma' do
    @one.premium = true
    @one.karma_description(9999).should eq 'Godly'
    @one.karma_description(400).should eq 'Angelic'
    @one.karma_description(0).should eq 'Neutral'
    @one.karma_description(-50).should eq 'Fair'
    @one.karma_description(-150).should eq 'Fair'
    @one.karma_description(-249).should eq 'Fair'
    @one.karma_description(-250).should eq 'Bad'
    @one.karma_description(-9999).should eq 'Unthinkable'

    @two.premium = false
    @two.karma_description(9999).should eq 'Godly'
    @two.karma_description(400).should eq 'Angelic'
    @two.karma_description(0).should eq 'Neutral'
    @two.karma_description(-75).should eq 'Fair'
    @two.karma_description(-149).should eq 'Fair'
    @two.karma_description(-150).should eq 'Bad'
    @two.karma_description(-9999).should eq 'Unthinkable'
  end

  describe 'PvP' do

    it 'should deplete my karma for bombing another player in a non-pvp zone' do
      @zone.pvp = false
      @one.position = @two.position = Vector2[5, 5]

      @zone.explode Vector2[5, 5], 10, @one
      @one.karma.should eq -10
    end

    it 'should not deplete my karma for bombing another player in a pvp zone' do
      @zone.pvp = true
      @one.position = @two.position = Vector2[5, 5]

      @zone.explode Vector2[5, 5], 10, @one
      @one.karma.should eq 0
    end

    it 'should not deplete my karma for bombing myself' do
      @one.position = Vector2[5, 5]
      @two.position = Vector2[20, 20]

      @zone.explode Vector2[5, 5], 10, @one
      @one.karma.should eq 0
    end

  end

  # it 'should deplete my karma for griefing another player' do
  #   grief @one, @two, 8
  #   @one.karma.should eq -8
  # end

  # it 'should deplete my karma more for griefing valuable items' do
  #   grief @one, @two, 8, Game.item_code('ground/onyx')
  #   @one.karma.should < -8
  # end

  # it 'should not deplete my karma for griefing dirt' do
  #   grief @one, @two, 10, Game.item_code('ground/earth')
  #   @one.karma.should eq 0
  # end

  # it 'should do nothing to my karma for mining non-owned blocks' do
  #   grief @one, nil, 100
  #   @one.karma.should eq 0
  # end

  # it 'should do nothing to my karma for mining blocks I own' do
  #   grief @one, @one, 100
  #   @one.karma.should eq 0
  # end

  # it 'should not ding my karma if I mine my followers blocks' do
  #   @one.followers = [@two.id]
  #   grief @one, @two, 100
  #   @one.karma.should eq 0
  # end

  # it 'should not ding my karma for mining blocks beneath my threshold' do
  #   @one.stub(:karma_block_threshold).and_return(-2)

  #   grief @one, @two, 8
  #   @one.karma.should eq 0

  #   grief @one, @two, 8, Game.item_code('ground/onyx')
  #   @one.karma.should < 8
  # end

  pending 'should send me griefing notifications to a premium player' do
    @one.premium = true
    @one.stub(:send_hint).and_return(nil) # Skip incremental hint messages (which are now dialog notifications)

    # 75
    grief @one, @two, 75
    @one.karma.should eq -75
    msgs = Message.receive_many(@one.socket, only: :notification)
    msgs.count.should eq 1
    msgs.first[:message].should =~ /Tsk tsk/

    # 150
    grief @one, @two, 75
    @one.karma.should eq -150
    msgs = Message.receive_many(@one.socket, only: :notification)
    msgs.first[:message].should =~ /careful/
    msgs.count.should eq 1

    # 250
    grief @one, @two, 100
    @one.karma.should < -250
    msgs = Message.receive_many(@one.socket, only: :notification)
    msgs.count.should eq 1
    msgs.first[:message].should =~ /bottomed out/
  end

  pending 'should send me griefing notifications to a free player' do
    @one.premium = false
    grief @one, @two, 150
    msgs = Message.receive_many(@one.socket, only: :notification)
    msgs.last.data.to_s.should =~ /bottomed out/
  end

  pending 'should send a premium player happy karma notifications' do
    @two.karma = -249

    10.times { Game.increment_karma }
    msgs = Message.receive_many(@two.socket, only: :notification)
    msgs.count.should eq 1
    msgs.first[:message].should =~ /better/
  end

  pending 'should send karma stat updates when karma decreases' do
    @two.karma = -74
#    Karma.decrement([@two], 1)
    stat = Message.receive_one(@two.socket, only: :stat)
    stat[:key].should eq ['karma']
    stat[:value].should eq ['Fair']
  end

  pending 'should send karma stat updates when karma increases' do
    @two.karma = -251

    10.times { Game.increment_karma }
    stat = Message.receive_one(@two.socket, only: :stat)
    stat[:key].should eq ['karma']
    stat[:value].should eq ['Fair']
  end

  pending 'should send one karma stat update when I lose a lot of karma' do
    @one.karma = 0

#    Karma.decrement(@one, 160)
    @one.karma.should eq -160
    stats = Message.receive_many(@one.socket, only: :stat)
    stats.size.should eq 1
  end

  pending 'should send one karma notification when I lose a lot of karma' do
    @one.karma = 0

#    Karma.decrement(@one, 160)
    @one.karma.should eq -160
    msgs = Message.receive_many(@one.socket, only: :notification)
    msgs.size.should eq 1
    msgs.first.data.to_s.should =~ /You should be more careful/
  end

  pending 'should remove an extra 10 karma when i hit -250' do
    @two.karma = -249

    @zone.update_block(nil, 0, 0, FRONT, @brass, 0, @one)
    BlockMineCommand.new([0, 0, FRONT, @brass, 0], @two.connection).execute!

    eventually { @two.karma.should eq -260 }
  end

  pending 'should remove ever more karma when i keep bottoming out' do
    @two.karma = -249
    @zone.update_block(nil, 0, 0, FRONT, @brass, 0, @one)
    BlockMineCommand.new([0, 0, FRONT, @brass, 0], @two.connection).execute!
    @two.karma.should eq -260

    @two.karma = -249
    @zone.update_block(nil, 0, 0, FRONT, @brass, 0, @one)
    BlockMineCommand.new([0, 0, FRONT, @brass, 0], @two.connection).execute!
    @two.karma.should eq -270
  end

  pending 'should not increment my karma above 0' do
    @one.karma = -5
    #7.times { Game.increment_karma }

    @one.karma.should eq 0
  end

end
