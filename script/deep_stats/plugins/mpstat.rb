class Mpstat

  def self.get_info
    if OS.mac?
      self.mac
    else
      self.linux
    end
  end

  private

  def self.mac
    raw = `top -i 1 -l 1 -n 1 -F -R`.split("\n")
    cpu = raw.select { |l| l.match /^\s*CPU usage:/ }.first.split(',')

    { cpu_u: u = cpu[0].split(':')[1].to_f,
      cpu_s: s = cpu[1].to_f,
      cpu_i: i = cpu[2].to_f,
      cores: [{u: u, s: s, i: i}] }
  end

  def self.linux
    raw = `mpstat -P ALL 5 1`.split("\n")

    cpus = raw.select { |l| l.match /^Average:/ }

    all = self.parse_row(cpus[1])
    cores = cpus[2..-1].map { |c| self.parse_row(c) }

    { cpu_u: all[:u],
      cpu_s: all[:s],
      cpu_i: all[:i],
      cores: cores }
  end

  def self.parse_row(raw)
    return {} if raw.nil?

    raw = raw.split
    { u: raw[2].to_f, s: raw[4].to_f, i: raw.last.to_f }
  end
end
