require "spec_helper"
include EntityHelpers

describe Minigames::Custom do

  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
    @two, @t_sock = auth_context(@zone)
    @two.position = 20, 5
    @three, @e_sock = auth_context(@zone)
    @three.position = 70, 5
    @zone = Game.zones[@zone.id]
    @zone.stub(:percent_explored).and_return(1.0)
    @item = Game.item("signs/obelisk")

    extend_player_reach @one, @two, @three
    @zone.owners << @one.id

    @earth = Game.item("ground/earth")
    @sandstone = Game.item("ground/sandstone")
    @pickaxe = Game.item("tools/pickaxe")
    @pickaxe_fine = Game.item("tools/pickaxe-fine")
    @pistol = Game.item("tools/pistol")
    @pistol_mk2 = Game.item("tools/pistol-mk2")
    @terrapus = 4
  end

  def place!
    add_inventory(@one, @item.code)
    command! @one, :block_place, [5, 5, FRONT, @item.code, 0]
  end

  def use_and_respond!(*uses)
    command! @one, :block_use, [5, 5, FRONT, []]

    uses.each_with_index do |use, idx|
      dialog = receive_msg!(@one, :dialog)
      dialog.should_not be_blank
      dialog_id = dialog.data.first
      command! @one, :dialog, [dialog_id, use]
    end
  end


  # ===== SETTING UP ===== #

  def verify_minigame!
    minigame = @zone.minigame_at_position(Vector2[5, 5])
    minigame.should be_a(Minigames::Custom)

    minigame.scoring_event.should eq :blocks_mined
    minigame.countdown_duration.should eq 8
    minigame.duration.should eq 45
    minigame.range.should eq 15

    minigame.tool_restriction.should eq @pickaxe.code
    minigame.block_restriction.should eq @earth.code
    minigame.entity_restriction.should eq @terrapus
    minigame.max_deaths.should eq 3
  end

  def begin_minigame!(scoring, restrictions = nil)
    restrictions ||= ["", "", "", "None", "All"]
    place!
    use_and_respond! ["customize"], [scoring, "Regular", "8", "45"], restrictions, []
    @zone.minigame_at_position(Vector2[5, 5])
  end

  def begin_advanced_minigame!(scoring)
    begin_minigame! scoring, [@pickaxe.code.to_s, @earth.code.to_s, @terrapus.to_s, "3", "All"]
  end

  describe "setup" do

    it "should customize a minigame" do
      begin_advanced_minigame! "Blocks mined"
      receive_msg!(@one, :notification).data.to_s.should =~ /Mine earths using a pickaxe/
      verify_minigame!
    end

    it "should copy settings from another minigame" do
      @record = MinigameRecordFoundry.create(
        code: "abcd33",
        scoring_event: "blocks_mined",
        range: 15,
        countdown_duration: 8,
        duration: 45,
        tool_restriction: @pickaxe.code,
        block_restriction: @earth.code,
        entity_restriction: @terrapus,
        max_deaths: 3,
        natural: "All"
      )
      place!
      use_and_respond! ["copy"], ["abCD33"], []

      verify_minigame!
    end

    it "should show details in a confirmation dialog" do
      place!
      use_and_respond! ["customize"], ["Blocks mined", "Regular", "8", "90"], [@pickaxe.code.to_s, @earth.code.to_s, @terrapus.to_s, "3", "All"]
      resp = receive_msg!(@one, :dialog).data.to_s
      resp.should =~ /Blocks Mined/
      resp.should =~ /15 blocks/
      resp.should =~ /8 seconds/
      resp.should =~ /1 minute, 30 seconds/
      resp.should =~ /Pickaxe/
      resp.should =~ /Earth/
      resp.should =~ /Adult Terrapus/
      resp.should =~ /3/
      resp.should =~ /All/
    end

    it "should show error and re-process dialog" do
      place!
      use_and_respond! ["customize"], ["Blocks mined", "Regular", "", ""], [], ["Blocks mined", "Regular", "8", "45"], [@pickaxe.code.to_s, @earth.code.to_s, @terrapus.to_s, "3", "All"], []
      verify_minigame!
    end

  end



  # ===== GAME MECHANICS ===== #

  it "should count down before beginning" do
    minigame = begin_advanced_minigame!("Blocks mined")
    minigame.step! 0
    receive_msg!(@one, :event).data.to_s.should =~ /8 seconds until/
    minigame.step! 0.5
    receive_msg(@one, :event).should be_nil
    minigame.step! 1
    receive_msg!(@one, :event).data.to_s.should =~ /7 seconds until/
    minigame.step! 6
    receive_msg!(@one, :event).data.to_s.should =~ /1 second until/
    minigame.step! 1
    receive_msg!(@one, :event).data.to_s.should =~ /The game has begun!/
  end

  it "should finish after countdown and full round duration elapses" do
    minigame = begin_advanced_minigame!("Blocks mined")
    10.times { minigame.step! 1.0 }
    minigame.time_remaining.should eq 43
  end

  it "should add players in range at beginning" do
    minigame = begin_advanced_minigame!("Blocks mined")
    minigame.participants.values.map(&:player).should =~ [@one, @two]
  end

  it "should add new players in range during game" do
    minigame = begin_advanced_minigame!("Blocks mined")
    @three.position = Vector2[10, 10]
    minigame.step! 0
    minigame.participants.values.map(&:player).should =~ [@one, @two, @three]
  end

  describe "mining" do

    it "should track mining of items" do
      minigame = begin_minigame!("Blocks mined")
      minigame.skip_countdown!
      @zone.update_block nil, 6, 6, FRONT, @sandstone.code
      command! @one, :block_mine, [6, 6, FRONT, @sandstone.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

    it "should respect block restriction when mining" do
      minigame = begin_minigame!("Blocks mined", ["", @earth.code.to_s, "", "None", "All"])
      minigame.skip_countdown!
      @zone.update_block nil, 6, 6, FRONT, @sandstone.code
      @zone.update_block nil, 7, 7, FRONT, @earth.code
      command! @one, :block_mine, [6, 6, FRONT, @sandstone.code, 0]
      command! @one, :block_mine, [7, 7, FRONT, @earth.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

    it "should respect tool restriction when mining" do
      minigame = begin_minigame!("Blocks mined", [@pickaxe.code.to_s, "", "", "None", "All"])
      minigame.skip_countdown!
      @zone.update_block nil, 6, 6, FRONT, @earth.code
      @zone.update_block nil, 7, 7, FRONT, @earth.code
      @one.stub(:current_item).and_return(111)
      command! @one, :block_mine, [6, 6, FRONT, @earth.code, 0]
      @one.stub(:current_item).and_return(@pickaxe.code)
      command! @one, :block_mine, [7, 7, FRONT, @earth.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

    it "should respect natural restriction when mining" do
      minigame = begin_minigame!("Blocks mined", ["", "", "", "None", "Natural"])
      minigame.skip_countdown!
      @zone.update_block nil, 6, 6, FRONT, @earth.code, 0, 1
      @zone.update_block nil, 7, 7, FRONT, @earth.code
      command! @one, :block_mine, [6, 6, FRONT, @earth.code, 0]
      command! @one, :block_mine, [7, 7, FRONT, @earth.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

    it "should respect range when mining" do
      minigame = begin_minigame!("Blocks mined", ["", "", "", "None", "Natural"])
      minigame.skip_countdown!
      @zone.update_block nil, 6, 6, FRONT, @earth.code
      @zone.update_block nil, 70, 7, FRONT, @earth.code
      command! @one, :block_mine, [6, 6, FRONT, @earth.code, 0]
      command! @one, :block_mine, [70, 7, FRONT, @earth.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

  end

  describe "placing" do

    pending "should track placing of items" do
      minigame = begin_minigame!("Blocks placed")
      minigame.skip_countdown!
      @one.inv.add @sandstone.code, 10
      @zone.update_block nil, 6, 6, FRONT, 0
      command! @one, :block_place, [6, 6, FRONT, @sandstone.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

    pending "should respect block restriction when placing" do
      minigame = begin_minigame!("Blocks placed", ["", @earth.code.to_s, "", "None", "All"])
      minigame.skip_countdown!
      @one.inv.add @sandstone.code, 10
      @one.inv.add @earth.code, 10
      @zone.update_block nil, 6, 6, FRONT, 0
      @zone.update_block nil, 7, 7, FRONT, 0
      command! @one, :block_place, [6, 6, FRONT, @sandstone.code, 0]
      command! @one, :block_place, [7, 7, FRONT, @earth.code, 0]
      minigame.get_participant(@one).score.should eq 1
    end

    pending "should respect range when placing" do
    end

  end

  describe "killing" do

    it "should track killing of players" do
      minigame = begin_minigame!("Players killed", ["", "", "", "None", "All"])
      minigame.skip_countdown!
      @two.die! @one
      minigame.get_participant(@one).score.should eq 1
    end

    it "should track killing of mobs" do
      minigame = begin_minigame!("Mobs killed", ["", "", "", "None", "All"])
      minigame.skip_countdown!
      entity = add_entity(@zone, 'terrapus/child')
      kill_entity @one, entity
      minigame.get_participant(@one).score.should eq 1
    end

    it "should respect mob restriction" do
      minigame = begin_minigame!("Mobs killed", ["", "", "4", "None", "All"])
      minigame.skip_countdown!
      entity = add_entity(@zone, 'terrapus/child')
      entity2 = add_entity(@zone, 'terrapus/adult')
      kill_entity @one, entity
      kill_entity @one, entity2
      minigame.get_participant(@one).score.should eq 1
    end

    pending "should respect tool restriction when killing" do
    end

    it "should respect range when killing" do
      minigame = begin_minigame!("Mobs killed", ["", "", "", "None", "All"])
      minigame.skip_countdown!
      entity = add_entity(@zone, 'terrapus/child')
      entity.position = Vector2[6, 6]
      entity2 = add_entity(@zone, 'terrapus/child')
      entity2.position = Vector2[70, 7]
      kill_entity @one, entity
      kill_entity @one, entity2
      minigame.get_participant(@one).score.should eq 1
    end

  end

  pending "should respect death restriction" do
  end

  describe "leaderboards" do

    before(:each) do
      @minigame = begin_minigame!("Blocks mined")
      @p_one = @minigame.get_participant(@one)
      @p_two = @minigame.get_participant(@two)
    end

    it "should notify of leaderboard position" do
      @p_one.stub(:ready_for_next_message?).and_return(true)
      @p_two.stub(:ready_for_next_message?).and_return(true)

      @p_one.score!
      receive_msg(@one, :event).should be_blank

      @minigame.update_leaderboard
      receive_msg!(@one, :event).data[1].should == "You are in 1st place with 1 block mined"
      receive_msg!(@two, :event).data[1].should == "You are in 2nd place with 0 blocks mined"

      @p_one.score!
      receive_msg!(@one, :event).data[1].should == "You are in 1st place with 2 blocks mined"

      @minigame.update_leaderboard
      receive_msg(@one, :event).should be_blank
      receive_msg(@two, :event).should be_blank

      @p_two.score!
      receive_msg!(@two, :event).data[1].should == "You are in 2nd place with 1 block mined"

      @minigame.update_leaderboard
      receive_msg(@one, :event).should be_blank
      receive_msg(@two, :event).should be_blank

      @p_two.score!
      receive_msg!(@two, :event).data[1].should == "You are in 2nd place with 2 blocks mined"

      @minigame.update_leaderboard
      receive_msg(@one, :event).should be_blank
      receive_msg!(@two, :event).data[1].should == "You are in 1st place with 2 blocks mined"

      @p_two.score!
      receive_msg!(@two, :event).data[1].should == "You are in 1st place with 3 blocks mined"

      @minigame.update_leaderboard
      receive_msg!(@one, :event).data[1].should == "You are in 2nd place with 2 blocks mined"
      receive_msg(@two, :event).should be_blank
    end

    it "should notify of single winner at finish" do
      @p_one.score!
      @minigame.finish!
      receive_many(@one, :notification)[-2].data[0].should eq "#{@one.name} won with 1 block mined!"
    end

    it "should notify of multiple winners at finish" do
      @p_one.score!
      @p_two.score!
      @minigame.finish!
      receive_many(@one, :notification)[-2].data[0].should eq "2-way tie! #{@one.name} and #{@two.name} won with 1 block mined!"
    end

    it "should notify of no winners at finish" do
      @minigame.finish!
      receive_many(@one, :notification)[-2].data[0].should =~ /Nobody scored any points/
    end

    it "should persist the minigame with leaderboard upon completion" do
      10.times { @p_one.score! }
      5.times { @p_two.score! }
      @minigame.finish!

      eventually do
        record = collection(:minigame_records).find.first
        record.should_not be_blank
        record["scoring_event"].should eq "blocks_mined"
        record["countdown_duration"].should eq 8
        record["duration"].should eq 45
        record["range"].should eq 15
        record["leaderboard"].should eq [[@one.id.to_s, 10], [@two.id.to_s, 5]]
        record["code"].should_not be_blank
        record["natural"].should eq "all"
      end
    end

  end

end


