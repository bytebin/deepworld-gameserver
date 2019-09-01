require 'spec_helper'

describe UnmuteCommand do
  describe 'With a zone and two players' do
    before(:each) do
      with_a_zone
      with_2_players(@zone)
    end

    it 'should unmute a player' do
      command @two, :console, ['mute', [@one.name]]
      Message.receive_one(@two.socket, only: :notification).data[0].should match "#{@one.name} has been muted."
      collection(:players).find_one(_id: @two.id)['mutings'].should eq ({@one.id.to_s => 0})
      @two.mutings.should eq ({@one.id.to_s => 0})

      command @two, :console, ['unmute', [@one.name]]
      Message.receive_one(@two.socket, only: :notification).data[0].should match "#{@one.name} has been unmuted."
      collection(:players).find_one(_id: @two.id)['mutings'].should eq ({@one.id.to_s => -1})
      @two.mutings.should eq ({@one.id.to_s => -1})
    end

    it 'should not unmute a player that is not muted' do
      command @two, :console, ['unmute', [@one.name]]
      Message.receive_one(@two.socket, only: :notification).data[0].should match "#{@one.name} is not muted."
      collection(:players).find_one(_id: @two.id)['mutings'].should be_nil
      @two.mutings.should eq ({})
    end

  end
end
