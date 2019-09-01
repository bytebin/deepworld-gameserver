require 'spec_helper'

describe Players::SkillUpgrade do

  before(:each) do
    with_a_zone
    with_a_player
    @one.points = 1
  end

  it 'should alert a player if they have no skill points' do
    @one.points = 0
    Players::SkillUpgrade.new(@one)
    expect(receive_msg_string!(@one, :dialog)).to match /out of skill points/
  end

  it 'should alert a player if they have no upgradeable skills' do
    @one.skills = Players::Skills::SKILLS.inject({}) do |hash, sk|
      hash[sk] = @one.max_skill_level; hash
    end
    Players::SkillUpgrade.new(@one)
    expect(receive_msg_string!(@one, :dialog)).to match /maxed/
  end

  it 'should inform a player more skills are unlockable if they are high level' do
    Players::SkillUpgrade.new(@one)
    expect(receive_msg_string!(@one, :dialog)).to match /Additional skills can be upgraded/
  end

  it 'should present a skill upgrade dialog' do
    Players::SkillUpgrade.new(@one)
    expect(receive_msg_string!(@one, :dialog)).to match /Choose a skill to upgrade/
  end

  it 'should not let a player upgrade without skill points' do
    @one.points = 0
    Players::SkillUpgrade.new(@one)
    expect(receive_msg!(@one, :dialog).data.to_s).to match /out of skill points/
  end

  it 'should not let a player upgrade if they lose skill points after dialog shows' do
    Players::SkillUpgrade.new(@one)
    dialog = receive_msg!(@one, :dialog)
    @one.points = 0

    command! @one, :dialog, [dialog.data[0], ['perception']]
    expect(receive_msg!(@one, :dialog).data.to_s).to match /out of skill points/
    @one.skill('perception').should eq 1
  end

  it 'should not let a player upgrade a non-upgradeable skill' do
    Players::SkillUpgrade.new(@one)
    dialog = receive_msg!(@one, :dialog)
    @one.skills['perception'] = 10

    command! @one, :dialog, [dialog.data[0], ['perception']]
    expect(receive_msg_string!(@one, :notification)).to match /maxed out/
    @one.skill('perception').should eq 10
  end

  it 'should upgrade a valid skill' do
    Players::SkillUpgrade.new(@one)
    dialog = receive_msg!(@one, :dialog)

    command! @one, :dialog, [dialog.data[0], ['perception']]
    expect(receive_msg_string!(@one, :notification)).to match /Perception upgraded to level 2/
    @one.skill('perception').should eq 2
  end

end
