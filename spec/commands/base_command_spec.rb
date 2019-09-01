require 'spec_helper'

describe BaseCommand do
  before(:each) do
    @zone = ZoneFoundry.create
    @one, @o_sock = auth_context(@zone)
  end

  it 'should report an error for a command initialized with the wrong parameters' do
    cmd = AuthenticateCommand.new([1], Game.connections[@zone.id].first)
    cmd.execute!

    cmd.errors.count.should eq 1
    cmd.errors.first.should match /Expected between 3/
  end
end
