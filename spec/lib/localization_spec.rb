require "spec_helper"

describe Loc do
  it "uses english" do
    Loc.t(:en, "test", param: "successful").should eq "English successful Test!"
    Loc.translate(:en, "test", param: "successful").should eq "English successful Test!"
  end

  it "uses german" do
    Loc.t(:de, "test", param: "erfolgreich").should eq "Deutsche erfolgreich Test!"
    Loc.translate(:de, "test", param: "erfolgreich").should eq "Deutsche erfolgreich Test!"
  end
end
