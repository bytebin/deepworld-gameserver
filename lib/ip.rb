class IP
  require "resolv"

  USER_AGENT = "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:12.0) Gecko/20100101 Firefox/12.0"
  IP_URL = "http://ip.bytebin.com/"

  def self.get_ip(cache_file = File.join(Deepworld::Loader.root, 'tmp', 'ip.txt'))
    cache_to_file(cache_file) do
      return 'localhost' if Deepworld::Env.local?

      begin
        ip_address = RestClient.get(IP_URL, user_agent: USER_AGENT) do |f|
          ip = /([0-9]{1,3}\.){3}[0-9]{1,3}/.match(f)
          ip.nil? ? nil : ip[0]
        end

        reverse_dns_lookup(ip_address)
      rescue Exception => e
        puts "Unable to fetch ip from #{IP_URL}"
        return nil
      end
    end
  end

  def self.reverse_dns_lookup(ip_address)
    (Resolv.getname(ip_address) rescue ip_address) || ip_address
  end

  def self.cache_to_file(location, &block)
    if File.exists?(location)
      ip = File.read(location).chomp
    else
      ip = yield
      File.open(location, 'w') { |f| f.puts ip }
    end

    ip
  end
end
