require 'spec_helper'

describe Items::Consumable do

  before(:each) do
    with_a_zone
    with_a_player @zone
  end

  it 'should apply stealthiness' do
    item = stub_item('stealther', { 'action' => 'stealth', 'power' => 5 })
    Items::Consumable.new(@one, item: item).use!

    @one.should be_stealthy
  end

  it 'should apply gift of premiumness' do
    @one.premium = false
    @one.should_not be_premium

    item = stub_item('gift', { 'action' => 'premium' })
    Items::Consumable.new(@one, item: item).use!

    msg = Message.receive_one(@one.socket, only: :stat)
    msg[:key].should eq ['premium']
    msg[:value].should eq [true]

    @one.should be_premium
  end

  it 'should not allow a premium gift use if already premium' do
    @one.premium = true
    item = stub_item('gift', { 'action' => 'premium' })
    Items::Consumable.new(@one, item: item).use!

    msg = Message.receive_one(@one.socket, only: :notification)
    msg.data[0].should eq 'You are already a premium player.'
  end

  describe 'skill bump' do

    before(:each) do
      @item = stub_item('bumper', { 'action' => 'skill', 'action_track' => 'skills_increased' })
      @one.stub(:skills_increased).and_return([])
    end

    it 'should allow a skill to be bumped' do
      use_skill_bump.should be_true
      skill_bump_dialog /which skill/i, true, ['Agility']
      reactor_wait
      receive_msg!(@one, :skill).data.to_s.should =~ /2/
      receive_msg!(@one, :dialog).data.to_s.should =~ /mastery/
      @one.skill('agility').should eq 2
      collection(:players).find_one(_id: @one.id)['skills_increased'].should eq ['agility']
    end

    it 'should only allow skills to be bumped that are not maxed' do
      @one.skills['agility'] = @one.max_skill_level
      use_skill_bump
      skill_bump_dialog /Agility/, false, ['Agility']
      reactor_wait
      @one.skill('agility').should eq @one.max_skill_level
      collection(:players).find_one(_id: @one.id)['skills_increased'].should be_nil
    end

    it 'should only allow skills to be bumped that have not already been increased' do
      @one.stub(:skills_increased).and_return(['agility'])
      use_skill_bump
      skill_bump_dialog /Agility/, false, ['Agility']
      reactor_wait
      @one.skill('agility').should eq 1
    end

    it 'should not allow a skill to be bumped if all skills are already bumped' do
      @one.stub(:skills_increased).and_return Players::Skills::SKILLS
      use_skill_bump.should be_false
      receive_msg!(@one, :notification).data.to_s.should =~ /already increased/
    end

    it 'should not allow a skill to be bumped if all skills are maxed' do
      @one.skills.keys.each do |key|
        @one.skills[key] = @one.max_skill_level
      end
      use_skill_bump.should be_false
      receive_msg!(@one, :notification).data.to_s.should =~ /maximized/
    end

    def use_skill_bump
      Items::Consumable.new(@one, item: @item).use!
    end

    def skill_bump_dialog(matcher = nil, should_match = true, response = nil)
      dialog = receive_msg!(@one, :dialog)
      dialog_id = dialog.data[0]
      data = dialog.data[1]
      if matcher
        if should_match
          data.to_s.should =~ matcher
        else
          data.to_s.should_not =~ matcher
        end
      end
      command! @one, :dialog, [dialog_id, response] if response
    end

  end

  describe 'skill reset' do

    it 'should subtract a point from each skill and add to points' do
      @one.points = 3
      @one.skills = { 'one' => 5, 'two' => 4, 'three' => 3, 'four' => 2 }

      item = stub_item('reset', { 'action' => 'skill reset' })
      Items::Consumable.new(@one, item: item).use!

      @one.points.should eq 7
      @one.skills.should eq({ 'one' => 4, 'two' => 3, 'three' => 2, 'four' => 1 })
    end

    it 'should not subtract and give points if a skill is at zero' do
      @one.points = 5
      @one.skills = { 'one' => 3, 'two' => 2, 'three' => 1, 'four' => 1 }

      item = stub_item('reset', { 'action' => 'skill reset' })
      Items::Consumable.new(@one, item: item).use!

      @one.points.should eq 7
      @one.skills.should eq({ 'one' => 2, 'two' => 1, 'three' => 1, 'four' => 1 })
    end

  end

end
