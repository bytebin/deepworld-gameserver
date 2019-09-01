require 'spec_helper'

describe Alert do
  it 'should create an alert' do
    Alert.create :testing, :critical, "Testing"

    eventually do
      alert = collection(:alerts).find_one
      alert['key'].should eq :testing
      alert['level'].should eq :critical
      alert['message'].should eq "Testing"
    end

  end
end