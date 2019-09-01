module Players
  module Jail

    def jailed?
      jailed
    end

    def send_to_jail
      jail_zone = Zone.where(name: 'Hell').callbacks(false).first do |zone|
        send_to zone.id, true
      end
    end

  end
end


