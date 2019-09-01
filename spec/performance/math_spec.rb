require 'spec_helper'

describe Math, performance: true do
  before(:each) do
    @start = Time.now
  end

  after(:each) do
    puts "Took #{Time.now - @start}s"
  end

  it "computes if within range" do
    10_000.times do
      Math.within_range?([rand(1400), rand(800)], [rand(1400), rand(800)], 50)
    end
  end

end