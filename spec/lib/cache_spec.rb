require 'spec_helper'

describe Cache do
  before(:each) do
    @cache = Cache.new
  end

  it "shouldn't have uncached stuff" do
    @cache.get(:stuff).should be_nil
  end

  it "should return a value for cached stuff" do
    @cache.set(:stuff, 42)
    @cache.get(:stuff).should eq 42
  end

  it "should cache stuff inline" do
    @cache.get(:stuff){42}.should eq 42
  end

  it "should give me fresh cached stuff" do
    @cache.set(:stuff, ['yay'])
    time_travel(0.20)

    @cache.get(:stuff, 0.25).should eq ['yay']
  end

  it "should not give me old cached stuff" do
    @cache.set(:stuff, 'hallo')
    time_travel(0.26)

    @cache.get(:stuff, 0.25).should be_nil
  end

  it "should clear everything" do
    @cache.set(:stuff, 'stuff')
    @cache.set(:things, 'things')
    @cache.clear!

    @cache.get(:stuff).should be_nil
    @cache.get(:things).should be_nil
  end

  it "should clear select keys" do
    @cache.set(:stuff, 'stuff')
    @cache.set(:things, 'things')
    @cache.clear(:stuff)

    @cache.get(:stuff).should be_nil
    @cache.get(:things).should eq "things"
  end

end
