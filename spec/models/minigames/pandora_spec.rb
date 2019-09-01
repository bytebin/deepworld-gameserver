require 'spec_helper'
include EntityHelpers

describe Minigames::Pandora do

  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @two, @t_sock = auth_context(@zone)
    @three, @e_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
    @zone.stub(:percent_explored).and_return(1.0)
    @pandora = Game.item('containers/pandora')
    @pandora_open = Game.item('containers/pandora-open')

    extend_player_reach @one, @two, @three
  end

  def place(activate = true)
    add_inventory(@one, @pandora.code)
    command! @one, :block_place, [5, 5, FRONT, @pandora.code, 0]
    if activate
      command! @one, :block_use, [5, 5, FRONT, []]
      dialog = Message.receive_one(@o_sock, only: :dialog)
      dialog.should_not be_blank
      dialog_id = dialog.data.first
      command! @one, :dialog, [dialog_id, []]
      @minigame = @zone.minigames.first
      @minigame.should_not be_blank
    end
  end

  it 'should not activate on placement' do
    place false
    @zone.minigames.should be_blank
  end

  it 'should not activate if no longer there' do
    place false
    command! @one, :block_use, [5, 5, FRONT, []]
    dialog = Message.receive_one(@o_sock, only: :dialog)
    dialog.should_not be_blank
    dialog_id = dialog.data.first
    @zone.update_block nil, 5, 5, FRONT, 0, 0
    command! @one, :dialog, [dialog_id, []]

    @zone.minigames.should be_blank
  end

  it 'should activate and send a message when used' do
    place true
    @zone.peek(5, 5, FRONT).should eq [@pandora_open.code, 1]
    @zone.minigames.should_not be_blank
    Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /You began a Pandora!/
    Message.receive_one(@t_sock, only: :notification).data.to_s.should =~ /#{@one.name} opened Pandora/
  end

  it 'should not activate again while activated' do
    place true
    command! @one, :block_use, [5, 5, FRONT, []]
    @zone.minigames.size.should eq 1
  end

  describe 'activated' do

    before(:each) do
      place true
      @minigame.stub(:max_rounds).and_return(4)
      @minigame.stub(:config).and_return(
        {
          'very easy' => [{ 'spawn' => { 'automata/tiny' => 5, 'automata/small' => 3 }}],
          'easy' => [{ 'spawn' => { 'automata/tiny' => 8, 'automata/small' => 5 }}],
          'medium' => [{ 'spawn' => { 'brains/small' => 5 }}],
          'hard' => [{ 'spawn' => { 'brains/medium' => 5 }}],
          'epic' => [{ 'spawn' => { 'brains/large' => 2 }}]
        }
      )
    end

    it 'should allow other players to increment the potency' do
      @minigame.potency.should eq 1
      command! @one, :block_use, [5, 5, FRONT, []]
      @minigame.potency.should eq 1
      command! @two, :block_use, [5, 5, FRONT, []]
      @minigame.potency.should eq 2
      command! @two, :block_use, [5, 5, FRONT, []]
      @minigame.potency.should eq 2
      command! @three, :block_use, [5, 5, FRONT, []]
      @minigame.potency.should eq 3
    end

    it 'should not allow other players to increment the potency after pandora begins' do
      @minigame.step! 61
      command! @two, :block_use, [5, 5, FRONT, []]
      @minigame.potency.should eq 1
    end

    it 'should initiate the game after the powering up period' do
      @minigame.stub(:incubation_duration).and_return(60)
      @minigame.step! 30
      @minigame.round.should eq 0
      @minigame.step! 31
      @minigame.round.should eq 1
    end

    it 'should spawn monsters in a round' do
      @minigame.round.should eq 0
      @minigame.step! 61
      @minigame.round.should eq 1
      10.times { @minigame.step! 2 }
      @minigame.round.should eq 1

      @zone.npcs.size.should eq 8
      @zone.npcs.count{ |npc| npc.ilk == Game.entity('automata/tiny').code }.should eq 5
      @zone.npcs.count{ |npc| npc.ilk == Game.entity('automata/small').code }.should eq 3
    end

    it 'should spawn more monsters if potency is higher' do
      command! @two, :block_use, [5, 5, FRONT, []]
      @minigame.step! 61
      10.times { @minigame.step! 2 }

      @zone.npcs.size.should eq 9
    end

    it 'should initiate the next round after monsters are killed' do
      @minigame.step! 61
      10.times { @minigame.step! 2 }

      npcs = @zone.npcs.dup
      npcs[0..-2].each{ |npc| npc.die! }
      @minigame.step! 10
      @zone.npcs.size.should eq 1
      npcs.last.die!
      @minigame.round.should eq 2

      10.times { @minigame.step! 2 }
      @zone.npcs.size.should eq 8
    end

    it 'should teleport monsters back to pandora if they wander too far' do
      @minigame.stub(:max_spawn_travel_distance).and_return(5)

      @minigame.step! 61
      10.times { @minigame.step! 2 }

      baddie = @minigame.spawns.first
      baddie.position = Vector2[19, 19]
      @minigame.step! 2
      (@minigame.origin - baddie.position).magnitude.should < 5
    end

    it 'should kill off remaining monsters and end the minigame if round max duration is passed' do
      @minigame.step! 61
      @minigame.stub(:max_round_duration).and_return(120)
      61.times { @minigame.step! 2 }
      @minigame.round.should eq 1
      @zone.minigames.size.should eq 0
      @zone.npcs.size.should eq 0
      Message.receive_many(@o_sock, only: :notification).last.data.to_s.should =~ /could not/
      @zone.peek(5, 5, FRONT).should eq [0, 0]
    end

    it 'should deactivate after all rounds are complete' do
      @minigame.step! 61
      4.times do |i|
        @minigame.should be_active
        @minigame.round.should eq i+1
        10.times { @minigame.step! 2 }
        @zone.npcs.dup.each{ |npc| npc.die! }
        @minigame.round.should eq i+2
      end

      @minigame.round.should eq 5
      @minigame.should_not be_active

      @zone.peek(5, 5, FRONT).should eq [0, 0]
    end

    it 'should notify players taking the lead' do
      @minigame.step! 61
      10.times { @minigame.step! 2 }
      Message.receive_many(@o_sock, only: :notification)

      @zone.npcs.first.die! @two
      @minigame.update_leaderboard
      Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /#{@two.name} took the lead/

      @zone.npcs.first(2).each{ |npc| npc.die! @three }
      @minigame.update_leaderboard
      Message.receive_one(@o_sock, only: :notification).data.to_s.should =~ /#{@three.name} took the lead/
    end

    it 'should notify that someone won and give them a prize' do
      @minigame.step! 61
      10.times { @minigame.step! 2 }

      @zone.npcs.first.die! @two
      @minigame.update_leaderboard
      Message.receive_many(@o_sock, only: :notification).last.data.to_s.should =~ /#{@two.name} took the lead/
      Message.receive_one(@t_sock, only: :inventory).should_not be_blank
    end

    it 'should go into complete state if end minigames is caled' do
      @zone.end_minigames
      @zone.peek(5, 5, FRONT).should eq [0, 0]
    end

    it 'should include itself as a spawn point' do
      @minigame.all_spawn_points.should include(@minigame.origin)
    end

  end
end
