require 'spec_helper'

describe MongoModel do
  class Spec < MongoModel
    fields [:one, :two]
  end

  it "should give me a count of matching documents" do
    @result = nil

    Spec.create({one: 'testing'}) do |result|
      Spec.count({one: 'testing'}) do |c|
        @result = c
      end
    end

    eventually { @result.should eq 1 }
  end

  it "should give me a random set" do
    @result = nil

    5.times.each { |i| collection(:spec).insert({one: i}) }

    Spec.random(3) do |s|
      @result = s
    end

    eventually { @result.count.should eq 3 }
  end

  it "should give me as many randoms as it can" do
    @result = nil

    3.times.each { |i| collection(:spec).insert({one: i}) }

    Spec.random(100) do |s|
      @result = s
    end

    eventually { @result.count.should eq 3 }
  end

  it "should increment a value" do
    collection(:spec).insert({one: 1})

    Spec.find_one do |s|
      s.inc(:one, 1) do |res|
        @result = res
      end
    end

    eventually { @result.one.should eq 2}
    collection(:spec).find_one['one'].should eq 2
  end

  it "should insert some models" do
    models = [{one: 1, two: 2},{one: 3, two: 4}]
    Spec.insert(models) do |ids|
      ids.count.should eq 2
    end

    eventually {collection(:spec).count.should eq 2}
  end

  it 'should pluck fields from the model' do
    5.times.each { |i| collection(:spec).insert({one: i, two: 'hello'}) }

    result = nil

    Spec.pluck({}, :one) do |pluck|
      result = pluck
    end

    eventually { result.should eq [[0],[1],[2],[3],[4]]}
  end

  it 'should reload a subset of fields' do
    collection(:spec).insert({one: 0, two: 1})
    result = nil

    Spec.find_one({one: 0}) do |spec|
      collection(:spec).update({one: 0}, {one: 1, two: 2})

      spec.reload(:one) do |res|
        result = res
      end
    end

    eventually { result.should_not be_nil}
    result.one.should eq 1
    result.two.should eq 1
  end
end
