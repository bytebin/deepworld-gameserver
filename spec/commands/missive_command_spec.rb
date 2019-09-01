require 'spec_helper'

describe MissiveCommand do

  describe 'responding to invites' do

    before(:each) do
      with_a_zone
      with_4_players
      @one.update facebook_id: '111'
      @two.update facebook_id: '222'
      @three.update facebook_id: '333'
      @four.update facebook_id: '444'

      command! @one, :facebook, ['invite', ['222', '333', '444']]
      reactor_wait
      reactor_wait
      collection(:invite).find.count.should eq 3
    end

    def respond_to_invite(player)
      missives = collection(:missive).find({ 'player_id' => player.id }).to_a
      command! player, :missive, ['respond', missives.first['_id'].to_s ]
    end

    xit 'should unlock a biome after three invites are confirmed' do
      [@two, @three, @four].each { |player| respond_to_invite player }
      eventually do
        collection(:invite).find({ 'responded' => true }).count.should eq 3
        collection(:player).find({ '_id' => @one.id }).to_a.first['upgrades'].should eq [Players::Invite::UPGRADES.first]
      end
    end

    xit 'should not unlock a biome if invites come from the same player' do
      [@two, @two, @two].each { |player| respond_to_invite player }
      eventually do
        collection(:invite).find({ 'responded' => true }).count.should eq 1
        collection(:player).find({ '_id' => @one.id }).to_a.first['upgrades'].should be_blank
      end
    end

    xit 'should tell a player they are making progress towards an upgrade' do
      respond_to_invite @two
      eventually do
        missive = collection(:missive).find({ 'player_id' => @one.id }).to_a.first
        missive['message'].should =~ /responded to your invite/
        missive['message'].should =~ /2 invites/
      end
    end

    xit 'should tell a player they unlocked an upgrade' do
      [@two, @three, @four].each { |player| respond_to_invite player }
      eventually do
        missive = collection(:missive).find({ 'player_id' => @one.id }).to_a.last
        missive['message'].should =~ /responded to your invite/
        missive['message'].should =~ /access to the Arctic biome/
      end
    end

    it 'should update the missive type' do
      respond_to_invite @two
      eventually do
        collection(:missive).find.to_a.first['type'].should eq 'invr'
      end
    end

    it 'should not mess with inventory' do
      @one.update inventory: { '512' => 100  }
      respond_to_invite @two
      reactor_wait
      reactor_wait
      reactor_wait
      collection(:player).find({ '_id' => @one.id }).to_a.first['inventory'].should eq({ '512' => 100 })
    end

  end

end
