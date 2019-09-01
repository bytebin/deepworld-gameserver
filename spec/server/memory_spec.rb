require 'spec_helper'

describe GameServer do
  before(:each) do
    Deepworld::Loader.load! %w{script/deep_stats/plugins script/deep_stats/os.rb}
  end

  xit 'should not leak memory' do
    baseline = memory_usage
    puts "Baseline memory usage: #{baseline}"

    zone = load_zone :large

    kill_zone zone
    usage = memory_usage

    usage.should be_within(1).of(baseline), "Memory went from #{baseline} to #{usage}. Lost #{usage - baseline}MB"
  end

  def load_zone(data_path = :huge)
    prev_count = Game.zones.count

    zone = ZoneFoundry.create(data_path: data_path)
    Game.load_zone(zone.id)

    eventually { Game.zones.count == prev_count + 1 }
    zone
  end

  def kill_zone(zone)
    prev_count = Game.zones.count

    zone.shutdown!

    eventually { Game.zones.count == prev_count - 1 }

    true
  end

  def memory_usage
    Top.get_info(Game.pid)[:procs].first[:mem_usage]
  end

end
