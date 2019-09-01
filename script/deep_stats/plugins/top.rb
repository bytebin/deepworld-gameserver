class Top
  example = <<-EXAMPLE
top - 22:59:26 up 19 days,  8:15,  1 user,  load average: 0.35, 0.33, 0.40
Tasks:   1 total,   0 running,   1 sleeping,   0 stopped,   0 zombie
Cpu(s):  1.0%us,  1.2%sy,  0.0%ni, 97.7%id,  0.0%wa,  0.0%hi,  0.0%si,  0.1%st
Mem:   1024092k total,   820260k used,   203832k free,    58944k buffers
Swap:   524284k total,     4604k used,   519680k free,   467860k cached

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
 3090 deepworl  20   0  233m 205m 5448 S   16 20.6 433:57.35 ruby

EXAMPLE

  def self.get_info(pids)
    pids = [pids].flatten
    return {} if pids.empty?

    if OS.mac?
      self.mac(pids)
    else
      self.linux(pids)
    end
  end

  private

  def self.mac(pids)
    raw = `top -stats pid,cpu,rsize,vsize -i 1 -l 1 -F -pid #{pids.join(',')}`.split("\n")
    procs = raw.select { |l| l.match /^\s*(#{pids.join('|')})\s/ }
    mem = raw.select { |l| l.match /^\s*PhysMem:/ }.first.split(',')

    processes = procs.map do |p|
      p = p.split
      {pid: p[0], cpu_util: p[1].to_f, mem_usage: normalize_top_memory(p[2]) }
    end

    mem_used = mem[3].to_i
    mem_free = mem[4].to_i

    {procs: processes, mem_used: mem_used, mem_free: mem_free}
  end

  def self.normalize_top_memory(memory)
    if memory.match /B$/
      0
    elsif memory.match /m$/
      memory.to_i
    elsif memory.match /g$/
      memory.to_f * 1024
    else
      memory.to_i / 1024
    end
  end

  def self.linux(pids)
    raw = `top -b -n 1 -p #{pids.join(',')}`.split("\n")
    procs = raw.select { |l| l.match /^\s*(#{pids.join('|')})\s/ }
    mem = raw.select { |l| l.match /\s*Mem:/ }.first.split(',')

    processes = procs.map do |p|
      p = p.split
      {pid: p[0], cpu_util: p[8].to_f, mem_usage: normalize_top_memory(p[5])}
    end

    mem_used = mem[1].to_i / 1024
    mem_free = mem[2].to_i / 1024

    {procs: processes, mem_used: mem_used, mem_free: mem_free}
  end
end
