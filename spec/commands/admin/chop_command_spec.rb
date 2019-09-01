require 'spec_helper'

describe ChopCommand do

  before(:each) do
    with_a_zone(data_path: :twohundo, size: Vector2.new(200,200), active: false)
    with_a_player(@zone, admin: true)
  end

  it 'should chop a zone to 100 x 100' do
    command! @one, :chop, [50, 50, 149, 149]

    eventually {
      @one.connection.disconnected.should be_true
    }

    @zone.size.should eq [100, 100]
  end

  it 'should adjust a zone chop to 120 x 120' do
    command! @one, :chop, [50, 50, 156, 165]

    eventually {
      @one.connection.disconnected.should be_true
    }

    @zone.size.should eq [120, 120]
  end
end
