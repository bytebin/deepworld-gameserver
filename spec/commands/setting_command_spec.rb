require 'spec_helper'

describe SettingCommand, :with_a_zone_and_player do

  it 'should allow players to set their visibility' do
    command! @player, :setting, ['visibility', 1]
    @player.settings['visibility'].should eq 1
  end
end