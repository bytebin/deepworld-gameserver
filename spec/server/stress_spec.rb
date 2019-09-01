require 'spec_helper'

class GameServer
  def pid
    Process.pid
  end
end

describe GameServer do
  before(:each) do
    Deepworld::Loader.load! %w{script/deep_stats/plugins script/deep_stats/os.rb}
  end

  xit 'should reclaim memory after zone shutdown' do

    initial = object_space_hash

    10.times do
      track_objects true, initial do
        track_memory do
          zone = load_zone :huge
          shutdown_zone(zone)
          GC.start
        end
      end
    end
  end


  xit 'should not leak serializing zone data' do
    zone = load_zone :huge
    initial = object_space_hash

    50.times do
      track_objects false, initial do
        track_memory do
          chunks = zone.kernel.chunks(false)

          GC.start
        end
      end
    end

    sleep 2

    puts "Object diff\n_________"
    pp object_space_diff(initial, object_space_hash)
  end
  xit 'should not leak when simulating everything' do
    PLAYERS = 10
    STEPS = 2000
    PERSISTS = 5

    initial = object_space_hash

    1000.times do |i|
      track_objects false, initial do
        track_memory do
          zone = load_zone :huge

          players = PLAYERS.times.map { register_player(zone, {position: [rand(zone.size.x), rand(zone.size.y)]}) }
          eventually { Game.players.count.should eq PLAYERS }
          STEPS.times { zone.step! }

          #players.each { |p| p.socket.close }
          shutdown_zone(zone)
          players.clear

          GC.start
        end
      end
    end
  end

  xit 'should not leak when loading many players' do
    zone = load_zone :huge

    10.times do |i|
      track_objects false do
        track_memory do
          players = 10.times.map { register_player(zone, {position: [rand(zone.size.x), rand(zone.size.y)]}) }
          players.each { |p| p.socket.close }
          players.clear
        end
      end
    end
  end

  def stress_test(iterations = 1)
    puts "Baseline memory usage: #{memory_usage}"

    initial_objects = object_space_hash

    iterations.times do |i|
      zone = load_zone :huge
      puts "Zone #{i + 1} loaded, memory usage: #{memory_usage}"

      kill_zone zone
      #sleep(1)
      puts "Zone #{i + 1} killed, memory usage: #{memory_usage}"

      if false
        ending_objects = object_space_hash

        puts "Object diff\n_________"
        pp object_space_diff(initial_objects, ending_objects)

        puts "Zones: #{ending_objects[Zone]} ZoneKernel::Zones: #{ending_objects[ZoneKernel::Zone]} ZoneKernel::Liquids: #{ending_objects[ZoneKernel::Liquid]}\n\n"

        initial_objects = ending_objects
      end
    end
  end

  def load_zone(data_path = :huge)
    prev_count = Game.zones.count

    zone = ZoneFoundry.create({data_path: data_path}, {callbacks: false})
    Game.load_zone zone.id

    while (Game.zones.count == prev_count) do
      sleep 1
    end

    raise "Couldn't load zone" unless Game.zones.count > prev_count

    zone = Game.zones[zone.id]
    zone.play

    zone
  end

  def kill_zone(zone)
    prev_count = Game.zones.count

    zone.shutdown!

    while (Game.zones.count > prev_count - 1) && count < 10 do
      sleep 1
    end

    true
  end

  def cpu_usage
    require 'debugger'; debugger

    top(Game.pid)[:procs].first[:mem_usage]
  end

  def memory_usage
    top(Game.pid)[:procs].first[:mem_usage]
  end

  def track_objects output = true, initial_objects = nil, &block
    if !output
      yield
    else
      GC.start
      initial_objects ||= object_space_hash

      yield

      puts "Object diff\n_________"
      pp object_space_diff(initial_objects, object_space_hash).first(10)
    end
  end

  def track_memory output = true, &block
    if !output
      yield
    else
      initial_memory = memory_usage

      yield

      mem = memory_usage
      puts "Memory usage: #{mem}Mb (#{memory_usage - initial_memory})"
    end
  end

  def object_space_hash
    types = {}

    ObjectSpace.each_object do |obj|
      types[obj.class] = 0 unless types[obj.class]
      types[obj.class] += 1
    end

    types
  end

  def object_space_diff(objects_start, objects_end)
    diff = {}
    objects_end.each do |klass, num|
      diff[klass] = num - (objects_start[klass] || 0)
    end

    diff.select{ |klass,num| num > 0}.sort_by{ |klass,num| -1 * num }
  end

  def top(pids)
    pids = [pids].flatten
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

  def symbol_count
    Symbol.all_symbols.count
  end

  def normalize_top_memory(memory)
    if memory.match /B$/
      0
    elsif memory.match /M\+$/
      memory.to_i
    elsif
      memory.to_i / 1024
    end
  end
end
