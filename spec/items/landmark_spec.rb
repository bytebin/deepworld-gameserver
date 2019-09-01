require 'spec_helper'
include EntityHelpers

describe Items::Landmark do

  before(:each) do
    with_a_zone
    with_3_players @zone

    @item = stub_item('item', 'meta' => 'hidden', 'use' => { 'landmark' => true })
    @zone.update_block @one, 5, 5, FRONT, @item.code
    @meta = @zone.get_meta_block(5, 5)
    @meta.player_id = @one.id.to_s
    @meta['n'] = 'Landmark'
    @meta['t1'] = 'Cool'
    @meta['t2'] = 'Spot'

    @time = Time.now
    Time.stub(:now).and_return(@time)
    @time = Time.now.to_i

    [@one, @two, @three].each{ |pl| pl.stub(:level).and_return(10) }
  end

  def landmark(player)
    Items::Landmark.new(player, position: Vector2[0, 0], meta: @meta, item: @item)
  end

  def landmark_doc
    collection(:landmark).find({ '_id' => BSON::ObjectId(@meta['landmark_id']) }).first
  end

  it 'should let players upvote a landmark' do
    landmark(@two).use_and_callback!
    @meta['v'].should eq({ @two.id.to_s => @time })

    Message.receive_one(@two.socket, only: :block_meta).should_not be_blank
    Message.receive_one(@two.socket, only: :notification).data.to_s.should =~ /Thanks for your upvote/

    landmark(@three).use_and_callback!
    @meta['v'].should eq({ @two.id.to_s => @time, @three.id.to_s => @time })
    @meta['vc'].should eq 2
  end

  it 'should progress a player towards a voting achievement' do
    landmark(@two).use_and_callback!
    @two.progress['landmarks upvoted'].should eq 1
  end

  it 'should change a landmarks mod if voted on' do
    landmark(@two).use_and_callback!
    @zone.peek(5, 5, FRONT)[1].should eq 1
  end

  it 'should not let low level players upvote a landmark' do
    @two.stub(:level).and_return(1)
    landmark(@two).use_and_callback!
    @meta['v'].should eq({})
    Message.receive_one(@two.socket, only: :notification).data.to_s.should =~ /level/
  end

  it 'should not a let a player upvote their own landmark' do
    landmark(@one).use_and_callback!
    @meta['v'].should eq({})
    Message.receive_one(@one.socket, only: :notification).data.to_s.should =~ /cannot/
  end

  it 'should not let a player upvote a landmark twice' do
    @two.stub(:landmark_last_vote_at).and_return(Time.now - 1.day)
    landmark(@two).use_and_callback!
    landmark(@two).use_and_callback!
    @meta['v'].should eq({ @two.id.to_s => @time })
    @meta['vc'].should eq 1

    Message.receive_many(@two.socket, only: :notification).last.data.to_s.should =~ /already upvoted/
  end

  it 'should not let a player upvote too many landmarks within a period' do
    landmark(@two).use_and_callback!
    @meta['v'] = {}
    landmark(@two).use_and_callback!
    Message.receive_many(@two.socket, only: :notification).last.data.to_s.should =~ /must wait/
  end

  it 'should increment the total upvotes for the landmark\'s creator' do
    landmark(@two).use_and_callback!
    landmark(@three).use_and_callback!

    eventually do
      player = collection(:players).find({ '_id' => @one.id }).first
      player['landmark_votes'].should eq 2
    end
  end


  describe 'persistence' do

    it 'should create a landmark document' do
      landmark(@one).persist!
      zone = @zone
      player = @one
      eventually do
        l = collection(:landmark).find.first
        l.should_not be_blank
        l['zone_id'].should eq zone.id
        l['player_id'].should eq player.id
        l['name'].should eq 'Landmark'
        l['description'].should eq 'Cool Spot'
        l['created_at'].should be_a(Time)
      end
    end

    it 'should create a landmark document when reaching enough votes' do
      Items::Landmark.stub(:persistence_vote_threshold).and_return(2)
      landmark(@two).use_and_callback!
      @meta['landmark_id'].should be_blank
      landmark(@three).use_and_callback!
      @meta['landmark_id'].should_not be_blank

      eventually do
        landmark_doc.should be_present
      end
    end

    it 'should update the vote count on a persisted landmark document' do
      l = landmark(@two)
      l.persist!
      reactor_wait
      landmark_doc['votes_count'].should eq 0
      l.class.stub(:persistence_vote_threshold).and_return(1)
      l.use_and_callback!
      reactor_wait
      landmark_doc['votes_count'].should eq 1
    end

    it 'should destroy a landmark document if the source block is removed' do
      landmark(@one).persist!
      eventually do
        collection(:landmark).find.first.should_not be_blank
      end
      @zone.update_block nil, 5, 5, FRONT, 0
      eventually do
        collection(:landmark).find.first.should be_blank
      end
    end

    it 'should migrate landmark documents in existing zones' do
      landmark(@two).use_and_callback!
      @zone.get_meta_block(5, 5).should eq @meta
      @meta['vc'].should eq 1
      eventually do
        collection(:landmark).find.first.should be_blank
      end
      Items::Landmark.stub(:persistence_vote_threshold).and_return(1)
      Migration0013.migrate(@zone)
      eventually do
        collection(:landmark).find.first.should_not be_blank
      end
    end

    describe 'in a competition' do

      before(:each) do
        @judge = @three
        @competition = CompetitionFoundry.create(judges: [@judge.id])
        @competition.after_initialize
        @zone.stub(:competition).and_return(@competition)
        @item = stub_item('landmark', { 'use' => { 'landmark' => 'competition' }})
      end

      it 'should create a landmark document with a competition if the zone is a competition zone' do
        landmark(@one).persist!
        eventually do
          collection(:landmark).find({ 'competition_id' => @competition.id }).first.should be_present
        end
      end

      it "should not allow any votes during a competition's active phase" do
        @competition.phase = Competition::ACTIVE
        landmark(@two).use_and_callback!
        landmark(@judge).use_and_callback!
        @meta['v'].should be_blank
        @meta['vn'].should be_blank
        @meta['vj'].should be_blank
      end

      it "should allow judges to nominate during a competition's nomination phase" do
        @competition.phase = Competition::NOMINATION
        landmark(@judge).use_and_callback!
        @meta['v'].should be_blank
        @meta['vn'].keys.should eq [@judge.id.to_s]
        @meta['vj'].should be_blank
      end

      it "should not allow player votes during a competition's nomination phase" do
        @competition.phase = Competition::NOMINATION
        landmark(@two).use_and_callback!
        @meta['v'].should be_blank
        @meta['vn'].should be_blank
        @meta['vj'].should be_blank
      end

      it "should allow judge votes on entries that have enough nominations during a competition's voting phase" do
        @competition.phase = Competition::JUDGING
        @competition.nomination_threshold = 3
        @meta['vn'] = { 'aaa' => 1, 'bbb' => 2, 'ccc' => 3 }
        @meta['vnc'] = 3

        l = landmark(@judge)
        l.should be_judge
        l.should_not be_improper_competition_phase
        l.vote_key.should eq 'vj'
        l.use_and_callback!.should be_true

        @meta['v'].should be_blank
        @meta['vj'].keys.should eq [@judge.id.to_s]
      end

      it "should not allow judge votes on entries that do not have enough nominations during a competition's voting phase" do
        @competition.phase = Competition::JUDGING
        @competition.nomination_threshold = 3
        @meta['vn'] = { 'aaa' => 1, 'bbb' => 2 }
        @meta['vnc'] = 2
        landmark(@judge).use_and_callback!

        @meta['v'].should be_blank
        @meta['vj'].should be_blank
      end

      it "should allow player votes on entries with enough nominations during a competition's voting phase" do
        @competition.phase = Competition::JUDGING
        @competition.nomination_threshold = 3
        @meta['vn'] = { 'aaa' => 1, 'bbb' => 2, 'ccc' => 3 }
        @meta['vnc'] = 3
        landmark(@two).use_and_callback!

        @meta['v'].keys.should eq [@two.id.to_s]
        @meta['vj'].should be_blank

        eventually do
          collection(:player).find({ '_id' => @two.id }).first['competition_votes'].should eq({ @competition.id.to_s => 1 })
        end
      end

      it "should not allow player votes on entries without enough nominations during a competition's voting phase" do
        @competition.phase = Competition::JUDGING
        @competition.nomination_threshold = 3
        @meta['vn'] = { 'aaa' => 1, 'bbb' => 2 }
        @meta['vnc'] = 2
        landmark(@two).use_and_callback!

        @meta['v'].should be_blank
        @meta['vj'].should be_blank
      end

      it 'should not allow a player to vote for more entries than the max number of votes' do
        @competition.phase = Competition::JUDGING
        @competition.nomination_threshold = 0
        @competition.max_votes = 5
        @two.stub(:competition_votes).and_return({ @competition.id.to_s => 5 })
        landmark(@two).use_and_callback!

        @meta['v'].should be_blank
        @meta['vj'].should be_blank
      end

      it 'should not allow any votes once competition is finished' do
        @competition.phase = Competition::FINISHED
        @competition.nomination_threshold = 0
        landmark(@two).use_and_callback!
        landmark(@judge).use_and_callback!

        @meta['v'].should be_blank
        @meta['vj'].should be_blank
      end

    end
  end
end