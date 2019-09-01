require 'spec_helper'

describe Deepworld::Settings do
  it 'should provide local settings to the application' do
    Deepworld::Settings.zone.spin_down.should_not be_nil
  end
end
