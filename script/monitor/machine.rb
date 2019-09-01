class Machine
  include Mongoid::Document

  field :ip_address, type: String
  field :restart, type: Boolean, default: false
  field :upgrade, type: Boolean, default: false
  field :quarantined, type: Boolean

  def self.register(ip_address)
    if machine = self.where({ip_address: ip_address}).first
      machine.update_attributes(restart: false, upgrade: false )
    else
      # Default the first machine registration to quarantined
      machine = self.create({ip_address: ip_address, restart: false, upgrade: false, quarantined: true})
    end

    machine
  end
end
