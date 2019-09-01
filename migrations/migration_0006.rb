module Migration0006
  def self.migrate(zone)
    # Zero out all ownership information
    zone.kernel.clear_owners
  end
end
