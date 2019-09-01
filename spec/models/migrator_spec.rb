require 'spec_helper'

describe Migrator do
  before(:each) do
    # Add to this list as you add migrations
    @migration_versions = [4,5,6,10,13,14,18]
    @migrator = Migrator.new
  end

  it 'should list all migrations' do
    @migrator.migrations.keys.should eq @migration_versions
  end

  it 'should report the latest version' do
    @migrator.latest.should eq @migration_versions.last
  end

  it 'should know the proper version to migrate to' do
    @migrator.migrations_to_run(nil).should eq @migration_versions
    @migrator.migrations_to_run(2).should eq @migration_versions
    @migrator.migrations_to_run(4).should eq @migration_versions - [4]
    @migrator.migrations_to_run(5).should eq @migration_versions - [4,5]
  end

  it 'should migrate a zone' do
    zone = ZoneFoundry.create(version: 2, migrated_version: nil)
    zone.migrated_version.should eq @migration_versions.last
  end
end
