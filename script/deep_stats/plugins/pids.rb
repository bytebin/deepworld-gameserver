class Pids
  example = <<-EXAMPLE
1000      2073     1  0 14:09 ?        00:00:00 su - deepworld -c cd /home/deepworld/game && PORT=5002 PRIMARY=true ruby deepworld.rb >> /var/log/deepworld/game-5002.log 2>&1
root      2074     1  0 14:09 ?        00:00:00 /bin/sh -e -c su - deepworld -c 'cd /home/deepworld/game && PORT=5001 ruby deepworld.rb >> /var/log/deepworld/game-5001.log 2>&1' /bin/sh
1000      2076  2074  0 14:09 ?        00:00:00 su - deepworld -c cd /home/deepworld/game && PORT=5001 ruby deepworld.rb >> /var/log/deepworld/game-5001.log 2>&1
1000      2080  2073  0 14:09 ?        00:00:00 -su -c cd /home/deepworld/game && PORT=5002 PRIMARY=true ruby deepworld.rb >> /var/log/deepworld/game-5002.log 2>&1
1000      2081  2076  0 14:09 ?        00:00:00 -su -c cd /home/deepworld/game && PORT=5001 ruby deepworld.rb >> /var/log/deepworld/game-5001.log 2>&1
1000      2087  2080  2 14:09 ?        00:03:37 ruby deepworld.rb
1000      2089  2081  2 14:09 ?        00:03:26 ruby deepworld.rb
EXAMPLE

  # Gets an array of pids
  def self.get_info(process_name)
    lines = `ps -ef | grep '#{process_name}' | grep -v grep`.split("\n")
    processes = lines.select { |l| l.match /\s#{process_name}$/ }
    pids = processes.map { |p| p.split(' ', 3)[1] } 
    
    pids
  end
end
