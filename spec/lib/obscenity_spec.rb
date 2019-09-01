require 'spec_helper'

describe Deepworld::Obscenity do
  it "should sanitize a phrase" do
    sanitized = Deepworld::Obscenity.sanitize("You are a fucker")
    sanitized.should_not match /fucker/
    sanitized.should match /f!!!er/
  end

  pending "should sanitize a phrase with emoji" do
    sanitized = Deepworld::Obscenity.sanitize("You are a f:smiley:ucker")
    sanitized.should_not match /f:smiley:ucker/
  end

  it 'should sanitize a phrase using transliteration' do
    sanitized = Deepworld::Obscenity.sanitize("You are a bîtch")
    sanitized.should_not match /b[îi]tch/
    sanitized.should match /b!!!!/
  end

  it 'should sanitize a phrase with unallowed characters' do
    sanitized = Deepworld::Obscenity.sanitize("You are a biすtch")
    sanitized.should match /b!!!!/
  end

  it "should leave non-offensive phrases alone" do
    Deepworld::Obscenity.sanitize("Hello jimmy, how's it goin").should eq "Hello jimmy, how's it goin"
  end

  it "should leave the casing on the first letter" do
    Deepworld::Obscenity.sanitize("You Shithead").should match /You S!!!head/
  end

  it "should report if a word is obscene" do
    Deepworld::Obscenity.is_obscene?("Fuckyland").should be_true
  end

  it "should not report if a world is not obscene" do
    Deepworld::Obscenity.is_obscene?("Helloland").should be_false
  end

  describe 'matches' do

    def obscene?(text)
      Deepworld::Obscenity.is_obscene?(text)
    end

    it 'should match a word with non-ascii characters' do
      obscene?('nîgga').should be_true
    end

    it 'should match words requiring an endline' do
      obscene?('ur a cock').should be_true
    end

    it 'should match words requiring a space' do
      obscene?('ur a cock too').should be_true
    end

    it 'should not match words in the middle' do
      obscene?('ur a cocker spaniel').should_not be_true
    end

  end
end
