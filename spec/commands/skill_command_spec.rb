require 'spec_helper'

describe SkillCommand do
  before(:each) do
    @zone = ZoneFoundry.create(data_path: :twentyempty)
    @one, @o_sock = auth_context(@zone)
    @zone = Game.zones[@zone.id]
  end

  it 'should allow a player to upgrade a skill if they have points' do
    @one.points = 1
    skill!.errors.should be_blank
    @one.points.should == 0
    @one.skills['agility'].should == 2
  end

  it 'should not allow me to upgrade a non-existant skill' do
    @one.points = 1
    skill!(nil, 'awesomepantsness').errors.should_not be_blank
    @one.points.should == 1
  end

  it 'should not allow a player to upgrade a skill if they do not have points' do
    skill!.errors.should_not be_blank
    @one.points.should == 0
    @one.skills['agility'].should == 1
  end

  it 'should not allow a premium player to upgrade skills past the max' do
    @one.points = 1
    @one.skills['agility'] = 10

    skill!.errors.should_not be_blank
    @one.points.should == 1
    @one.skills['agility'].should == 10
  end

  it 'should allow a free player to upgrade skills past 3' do
    @one.points = 1
    @one.premium = false
    @one.skills['agility'] = 3

    skill!.errors.should be_blank
    @one.points.should == 0
    @one.skills['agility'].should == 4
  end

  it 'should allow an admin to set a skill' do
    @one.admin = true
    bloop = skill!(5).errors

    skill!(5).errors.should be_blank
    @one.skills['agility'].should == 5
  end

  it 'should not allow a non-admin to set a skill' do
    skill!(5).errors.should_not be_blank
    @one.skills['agility'].should == 1
  end

  it 'should compute a skill level' do
    @one.skills['agility'] = 3
    @one.skills['mining'] = 5
    @one.skill_level.should == 7
  end

  def skill!(level = nil, skill = 'agility')
    cmd = SkillCommand.new([skill, level], @one.connection)
    cmd.execute!
    cmd
  end

end