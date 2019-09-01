require 'spec_helper'

describe Rect do
  before(:each) do
    @rect = Rect[0, 0, 5, 5]
  end
  it "should contain a coordinate inside" do
    @rect.contains?([3, 4]).should be_true
  end

  it "should contain a coordinate at the edges" do
    @rect.contains?([5, 5]).should be_true
    @rect.contains?([0, 0]).should be_true
    @rect.contains?([0, 5]).should be_true
    @rect.contains?([5, 0]).should be_true
    @rect.contains?([0, 3]).should be_true
    @rect.contains?([3, 0]).should be_true
    @rect.contains?([3, 5]).should be_true
    @rect.contains?([5, 5]).should be_true
  end

  it "should not contain outside coordinates" do
    @rect.contains?([6, 0]).should be_false
    @rect.contains?([0, 6]).should be_false
    @rect.contains?([15, 15]).should be_false
  end
end
