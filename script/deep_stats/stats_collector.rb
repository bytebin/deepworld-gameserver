require 'net/http'
require 'uri'

class StatsCollector
  PID_REFRESH = 60

  def initialize(process_string)
    @pids = get_process_ids(process_string)
    @last_pid = Time.now.to_i

    @process_string = process_string
    @hostname = get_hostname
    @ip = IP.get_ip(File.join(Deepworld::Loader.root, '../../tmp/ip.txt'))
  end

  def collect
    # Refresh pid list every so often in case of crashes
    if Time.now.to_i - @last_pid >= PID_REFRESH
      @pids = get_process_ids(@process_string)
      @last_pid = Time.now.to_i
    end

    top = Top.get_info(@pids)
    mpstat = Mpstat.get_info

    { ip: @ip,
      created_at: Time.now,
      procs: top[:procs],
      mem_used: top[:mem_used],
      mem_free: top[:mem_free],
      cpu_u: mpstat[:cpu_u],
      cpu_s: mpstat[:cpu_s],
      cpu_i: mpstat[:cpu_i],
      cores: mpstat[:cores]
    }
  end

  private

  def get_hostname
    `hostname`.chomp
  end

  def get_process_ids(process_string)
    Pids.get_info(process_string)
  end
end
