class Migrator
  def migrate(zone)
    self.migrations_to_run(zone.migrated_version).each do |v|
      Game.info message: "Migrating #{zone.name} to version #{v}....", zone_id: zone.id
      self.migrations[v].migrate(zone)
      zone.update migrated_version: v
    end
  end

  def migrations
    @migrations ||= discover_migrations
  end

  def discover_migrations
    # Get the module names from the migration files
    files = Dir.glob(File.expand_path('../**', __FILE__)) - [__FILE__]
    files = files.map{|f| f.split('/').last.split('.').first.camelize }.sort

    # Create a version hash
    migs = {}
    files.each{|f| migs[f[-4..-1].to_i] = f.constantize}

    migs
  end

  def latest
    self.migrations.keys.last
  end

  def migrations_to_run(migrated_version)
    return self.migrations.keys.sort if migrated_version.nil?
    return [] if migrated_version > latest

    self.migrations.keys.select{|v| v > migrated_version}.sort
  end
end