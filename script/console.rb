require 'bundler'
require 'mongo'

Bundler.require

require File.expand_path('../../config/initializers/load_paths.rb', __FILE__)
LOADER = Deepworld::Loader.load!(LOAD_PATHS)
include Eventually

def load_player(name, environment)
  if player = Deepworld::DB.collection(:players, environment).find_one(name_downcase: name.downcase)
    collection(:players).update({name_downcase: player['name_downcase']}, player.except('_id'), { upsert: true})
  else
    puts "Sorry no player named '#{name} in #{environment} environment"
  end

  player
end

def copy_player(name, from_env, to_env = :development)
  from_env = from_env.downcase.to_sym
  to_env = to_env.downcase.to_sym

  unless player = Deepworld::DB.collection(:players, from_env).find_one(name: name)
    puts "Sorry no player named '#{name}' in #{from_env} environment"
    return nil
  end

  # Persist the doc
  Deepworld::DB.collection(:players, to_env).update({name: name}, player.except("_id"), { upsert: true })
  puts "#{name} copied from #{from_env} to #{to_env}."

  player
end

def start_zone(zone_name)
  prev_count = Game.zones.count
  zone = collection(:zones).find_one(name: zone_name)

  if zone
    collection(:zones).update({'_id' => zone['_id']}, {'$set' => { 'server_id' => Game.document_id}})
    Game.load_zone(zone['_id'])

    eventually { raise "nope" unless Game.zones.count == prev_count + 1 }

    return get_running_zone(zone_name) if Game.zones.count == prev_count + 1
  end

  nil
end

def stop_zone(zone_name)
  prev_count = Game.zones.count

  if zone = get_running_zone(zone_name)
    zone.shutdown!
    eventually { raise "nope" unless Game.zones.count <= prev_count - 1 }
  end
end

def start_random_zone
  start_zone list_zones.random
end


def copy_zone(zone_name, from_env, to_env, new_name = nil)
  from_env = from_env.downcase.to_sym
  to_env = to_env.downcase.to_sym

  unless zone = Deepworld::DB.collection(:zones, from_env).find_one(name: zone_name)
    puts "Sorry no zone named '#{zone_name}' in #{from_env} environment"
    return nil
  end

  # TODO: Remove block once zone versioning is complete
  if zone['file_version'].nil?
    zone = copy_zone_old(zone_name, from_env, to_env, new_name)
    return zone
  end
  ###################

  original_path = zone['data_path'].split('.').insert(-2, zone['file_version']).join('.')
  zone['name'] = new_name if new_name

  if from_env == :development
    if (to_env == :development)
      previous_file = zone['data_path'].split('/').last
      new_file = Deepworld::Token.unique_path.split('/').last + ".zone"

      File.open File.join(Deepworld::Env.root, 'tmp', new_file), 'wb' do |f|
        f.write(File.read("tmp/#{previous_file}"))
      end

      zone['data_path'] = new_file
    else
      local_path = zone['data_path'].split('/').last
      to_bucket = Deepworld::Settings.peek(to_env).fog.zone_bucket

      path = Deepworld::Token.unique_path
      data_path = "#{path}/#{path.split('/').last}.zone.gz"
      versioned_data_path = data_path.split('.').insert(-2, 1).join('.')

      io = StringIO.new('w')
      gz = Zlib::GzipWriter.new(io, 5)
      gz.write File.read("tmp/#{local_path}")
      gz.close

      zone['file_versioned_at'] = Time.now.utc
      zone['file_version'] = 1
      zone['data_path'] = data_path

      S3.put_object to_bucket, versioned_data_path, io.string, {'x-amz-acl' => 'private'}
    end
  elsif to_env == :development
    filename = zone['data_path'].split('/').last
    new_path = filename.split('.')[0..-2].join('.')

    from_bucket = Deepworld::Settings.peek(from_env).fog.zone_bucket

    File.open File.join(Deepworld::Env.root, 'tmp', new_path), 'wb' do |f|
      zone_request = S3.get_object(from_bucket, original_path)
      zone_request_io = StringIO.new(zone_request.body)
      f.write Zlib::GzipReader.new(zone_request_io).read
    end

    zone['data_path'] = new_path
  else
    from_bucket = Deepworld::Settings.peek(from_env).fog.zone_bucket
    to_bucket = Deepworld::Settings.peek(to_env).fog.zone_bucket

    if new_name
      path = Deepworld::Token.unique_path
      data_path = "#{path}/#{path.split('/').last}.zone.gz"
      new_path = data_path.split('.').insert(-2, zone['file_version']).join('.')

      zone['data_path'] = data_path
    else
      new_path = original_path
    end

    S3.copy_object(from_bucket, original_path, to_bucket, new_path)
  end

  # Persist the doc
  Deepworld::DB.collection(:zones, to_env).update({name: zone['name']}, zone.except("_id"), { upsert: true })
  puts "#{zone_name} copied from #{from_env} to #{to_env}."

  zone
end

def copy_characters(from_zone, from_env, to_zone, to_env)
  unless from = Deepworld::DB.collection(:zones, from_env).find_one(name: from_zone)
    puts "Sorry no zone named '#{from_zone}' in #{from_env} environment"
    return nil
  end

  unless to = Deepworld::DB.collection(:zones, to_env).find_one(name: to_zone)
    puts "Sorry no zone named '#{to_zone}' in #{to_env} environment"
    return nil
  end

  chars = Deepworld::DB.collection(:characters, from_env).find(zone_id: from['_id'])

  collection = Deepworld::DB.collection(:characters, to_env)

  chars.each do |c|
    c['zone_id'] = to['_id']
    collection.update({'zone_id' => to['_id'], 'name' => c['name']}, c.except("_id"), { upsert: true })

    puts "Copied #{c['name']} to #{to['_id']}"
  end
end

def load_zone(zone_name, environment, new_name = nil)
  copy_zone zone_name, environment, :development, new_name
end

def make_admin(player_name)
  collection(:players).update({name_downcase: player_name.downcase}, {'$set' => {admin: true}})
end

def collection(collection_name)
  Deepworld::DB.collection(collection_name, Deepworld::Env.environment)
end

def delete_player(player_name)
  collection('players').remove({name_downcase: player_name.downcase})
end

def on_all_coordinates(zone_name, &block)
  zone = get_running_zone(zone_name)

  (0..(zone.size.x - 1)).each do |x|
    (0..(zone.size.y - 1)).each do |y|
      yield zone, x, y
    end
  end
end

def get_running_zone(name)
  Game.zones.detect {|z| z[1].name == name}[1]
end

def list_zones(search = nil)
  if search
    crit = collection(:zones).find({name: /#{search}/i})
  else
    crit = collection(:zones).find
  end

  crit.to_a.map{|z| z['name']}
end

def destroy_guild(guild_name)
  if guild = collection(:guilds).find_one({name: guild_name})
    pids = [[guild[:members]] + [guild[:leader_id]]].flatten.compact

    collection(:players).update({guild_id: guild['_id']}, {'$set' => {guild_id: nil}}, multi: true)
    collection(:guilds).remove({name: guild_name})
  else
    puts "Guild #{guild_name} not found"
  end
end

def self.inspect_zone_versions(zone_name, environment = :production, all = false)
  output = []

  Deepworld::Zone.list_versions(zone_name, environment, all).each do |v|
    ver = v['Version'] || v['DeleteMarker']

    out = "#{ver['Key']} #{ver['LastModified']} #{ver['VersionId']} #{ver['Size']} #{ver['IsLatest']}"
    out += " X" if v['DeleteMarker']

    output << out
    nil
  end

  puts output.reverse.join("\n")
  true
end

def self.lookup_zone(zone_name, environment = :production)
  Deepworld::DB.collection(:zones, environment).find({name: zone_name}).first
end

def self.lookup_player(player_name, environment = :production)
  Deepworld::DB.collection(:players, environment).find({name: player_name}).first
end

def self.recent_sessions(zone_name, environment = :production)
  zone = self.lookup_zone(zone_name, environment)
  Deepworld::DB.collection(:sessions, environment).find({started_at: {'$gt' => Time.now - 24.hours}, zone_id: zone['_id']}).to_a
end

def object_space_hash
  types = {}

  ObjectSpace.each_object do |obj|
    types[obj.class] = 0 unless types[obj.class]
    types[obj.class] += 1
  end

  types
end

def object_space_diff(initial_objects, ending_object_space_hash)
  diff = {}
  ending_object_space_hash.each do |klass, num|
    diff[klass] = num - (initial_objects[klass] || 0)
  end
  diff.select{ |klass,num| num > 0}.sort_by{ |klass,num| -1 * num }
end

if ENV['RUN'].to_bool
  Game = GameServer.new
  game_thread = Thread.new { Game.boot! }
end

####################################
# NORTH MARKET STUFF
####################################

def diffs!
  start_zone 'North Market'
  start_zone 'North Market Backup'
  sleep 3

  Game.zones.values.each
  Game.zones.values.each do |z|
    if z.name == "North Market"
      @market = z
    else
      @backup = z
    end
  end

  @diff_indexes = @backup.meta_blocks.keys - @market.meta_blocks.keys
  @diffs = @backup.meta_blocks.values_at *@diff_indexes

  nil
end

def block_owners(zone)
  blocks = []

  (0..zone.size.y-1).each do |y|
    puts y
    blocks[y] = Array.new(zone.size.x)

    (0..zone.size.x-1).each do |x|
      puts x
      blocks[y][x] = block_owned_by(zone, [x,y])
    end
  end

  blocks
end

def block_owned_by(zone, position)
  item = Game.item(zone.peek(position.x, position.y, FRONT)[0])
  meta_block = zone.get_meta_block(position.x, position.y)

  # Verify force fields
  protectors ||= zone.protectors_in_range(position)
  protectors.each do |meta|
    if player_id = meta.player_id
      return player_id
    end
  end

  return 0
end

def duplicate_inventory(zone)
  legal = legal_changes(zone)

  inventory = {}

  legal.each do |i|
    inventory[i[:player_id]] ||= {}
    inventory[i[:player_id]][i[:item]] ||= 0

    inventory[i[:player_id]][i[:item]] += 1
  end

  inventory
end

def illegal_inventory(zone)
  illegal = illegal_changes(zone)

  inventory = {}

  illegal.each do |i|
    inventory[i[:player_id]] ||= {}
    inventory[i[:player_id]][i[:item]] ||= 0

    inventory[i[:player_id]][i[:item]] += 1
  end

  inventory
end

def legal_changes(zone)
  legal = []

  changes.each do |change|
    legal << change if block_owned_by(@backup, change[:location]) == change[:player_id]
  end

  legal
end

def illegal_changes(zone)
  illegal = []

  changes.each do |change|
    illegal << change if block_owned_by(@backup, change[:location]) != change[:player_id]
  end

  illegal
end

def changes
  [{id: '54325cf4421aa90165001107', player_id: '5130a6615109c0eafd00006e', item: 604, location: [1132, 92]},
  {id: '54325cf4421aa90165001108', player_id: '5130a6615109c0eafd00006e', item: 604, location: [1133, 97]},
  {id: '54325d1d421aa90165001129', player_id: '5130a6615109c0eafd00006e', item: 966, location: [1113, 103]},
  {id: '54325f51421aa90165001215', player_id: '512e9d105a605ca4f3000004', item: 580, location: [634, 227]},
  {id: '54325f51421aa90165001216', player_id: '512e9d105a605ca4f3000004', item: 580, location: [634, 226]},
  {id: '54325f56421aa90165001218', player_id: '512e9d105a605ca4f3000004', item: 580, location: [633, 227]},
  {id: '54325f5b421aa9016500121c', player_id: '512e9d105a605ca4f3000004', item: 580, location: [633, 226]},
  {id: '54326523421aa90165001345', player_id: '536d36ba109873023f00011a', item: 969, location: [669, 73]},
  {id: '54326528421aa90165001347', player_id: '536d36ba109873023f00011a', item: 969, location: [671, 73]},
  {id: '54326528421aa90165001348', player_id: '536d36ba109873023f00011a', item: 979, location: [675, 73]},
  {id: '5432652d421aa9016500134a', player_id: '536d36ba109873023f00011a', item: 997, location: [673, 68]},
  {id: '543267fa421aa90165001402', player_id: '51d3ee828e08fd5752000013', item: 849, location: [869, 150]},
  {id: '54326855421aa90165001431', player_id: '53d033584df262cc8c000126', item: 305, location: [1227, 60]},
  {id: '54326887421aa90165001457', player_id: '51d3ee828e08fd5752000013', item: 849, location: [820, 120]},
  {id: '543268a6421aa9016500146b', player_id: '51d3ee828e08fd5752000013', item: 849, location: [819, 124]},
  {id: '543268b5421aa90165001478', player_id: '52c64223761ba6e89f00001b', item: 580, location: [950, 341]},
  {id: '543268ba421aa9016500147f', player_id: '52c64223761ba6e89f00001b', item: 854, location: [948, 344]},
  {id: '543268bf421aa90165001483', player_id: '52c64223761ba6e89f00001b', item: 831, location: [946, 343]},
  {id: '543268bf421aa90165001484', player_id: '52c64223761ba6e89f00001b', item: 637, location: [945, 344]},
  {id: '543268bf421aa90165001486', player_id: '52c64223761ba6e89f00001b', item: 930, location: [943, 344]},
  {id: '543268bf421aa90165001487', player_id: '5382e9a69c294844b300009b', item: 794, location: [868, 344]},
  {id: '543268bf421aa90165001488', player_id: '52c64223761ba6e89f00001b', item: 785, location: [948, 341]},
  {id: '543268c4421aa9016500148e', player_id: '52c64223761ba6e89f00001b', item: 910, location: [944, 341]},
  {id: '543268c4421aa9016500148f', player_id: '52c64223761ba6e89f00001b', item: 643, location: [949, 343]},
  {id: '543268c9421aa90165001490', player_id: '52c64223761ba6e89f00001b', item: 794, location: [951, 344]},
  {id: '543268c9421aa90165001491', player_id: '52c64223761ba6e89f00001b', item: 750, location: [951, 341]},
  {id: '543268f2421aa901650014ab', player_id: '51d3ee828e08fd5752000013', item: 849, location: [812, 136]},
  {id: '54326916421aa901650014ba', player_id: '5382e9a69c294844b300009b', item: 583, location: [895, 586]},
  {id: '54326916421aa901650014bb', player_id: '5382e9a69c294844b300009b', item: 583, location: [896, 586]},
  {id: '54326916421aa901650014bc', player_id: '5382e9a69c294844b300009b', item: 580, location: [895, 583]},
  {id: '54326916421aa901650014bd', player_id: '5382e9a69c294844b300009b', item: 580, location: [896, 583]},
  {id: '5432691b421aa901650014c2', player_id: '5382e9a69c294844b300009b', item: 581, location: [897, 586]},
  {id: '5432691b421aa901650014c3', player_id: '5382e9a69c294844b300009b', item: 581, location: [898, 586]},
  {id: '5432691b421aa901650014c4', player_id: '5382e9a69c294844b300009b', item: 584, location: [897, 584]},
  {id: '5432691b421aa901650014c5', player_id: '5382e9a69c294844b300009b', item: 580, location: [897, 583]},
  {id: '5432691b421aa901650014c6', player_id: '5382e9a69c294844b300009b', item: 580, location: [898, 583]},
  {id: '5432691b421aa901650014c7', player_id: '5382e9a69c294844b300009b', item: 584, location: [898, 584]},
  {id: '5432691b421aa901650014c8', player_id: '5382e9a69c294844b300009b', item: 584, location: [899, 584]},
  {id: '5432691b421aa901650014c9', player_id: '5382e9a69c294844b300009b', item: 581, location: [899, 586]},
  {id: '5432691b421aa901650014ca', player_id: '5382e9a69c294844b300009b', item: 580, location: [899, 583]},
  {id: '54326920421aa901650014cb', player_id: '5382e9a69c294844b300009b', item: 780, location: [897, 589]},
  {id: '54326920421aa901650014cc', player_id: '5382e9a69c294844b300009b', item: 780, location: [895, 590]},
  {id: '54326920421aa901650014cd', player_id: '5382e9a69c294844b300009b', item: 585, location: [897, 590]},
  {id: '5432694d421aa901650014dd', player_id: '52c64223761ba6e89f00001b', item: 854, location: [942, 343]},
  {id: '5432698a421aa901650014ef', player_id: '5251d49cf46fe5fe1700014d', item: 849, location: [1168, 450]},
  {id: '5432698a421aa901650014f0', player_id: '5251d49cf46fe5fe1700014d', item: 914, location: [1170, 451]},
  {id: '5432699e421aa901650014fc', player_id: '52c64223761ba6e89f00001b', item: 854, location: [944, 343]},
  {id: '543269d1421aa90165001511', player_id: '52c64223761ba6e89f00001b', item: 830, location: [955, 341]},
  {id: '54326a1d421aa90165001533', player_id: '51d3ee828e08fd5752000013', item: 849, location: [65, 23]},
  {id: '54326a22421aa90165001535', player_id: '52c64223761ba6e89f00001b', item: 640, location: [945, 342]},
  {id: '54326a31421aa9016500153a', player_id: '5251d49cf46fe5fe1700014d', item: 854, location: [1079, 541]},
  {id: '54326a31421aa9016500153b', player_id: '5251d49cf46fe5fe1700014d', item: 797, location: [1080, 539]},
  {id: '54326a3c421aa90165001541', player_id: '52c64223761ba6e89f00001b', item: 967, location: [953, 301]},
  {id: '54326a3c421aa90165001542', player_id: '52c64223761ba6e89f00001b', item: 967, location: [958, 303]},
  {id: '54326a41421aa90165001545', player_id: '52c64223761ba6e89f00001b', item: 967, location: [962, 302]},
  {id: '54326a41421aa90165001546', player_id: '52c64223761ba6e89f00001b', item: 967, location: [962, 300]},
  {id: '54326a46421aa90165001548', player_id: '52c64223761ba6e89f00001b', item: 807, location: [957, 300]},
  {id: '54326a46421aa90165001549', player_id: '52c64223761ba6e89f00001b', item: 807, location: [955, 299]},
  {id: '54326a46421aa9016500154a', player_id: '52c64223761ba6e89f00001b', item: 782, location: [961, 295]},
  {id: '54326a46421aa9016500154b', player_id: '52c64223761ba6e89f00001b', item: 782, location: [960, 295]},
  {id: '54326a46421aa9016500154c', player_id: '52c64223761ba6e89f00001b', item: 310, location: [958, 295]},
  {id: '54326a4b421aa90165001550', player_id: '52c64223761ba6e89f00001b', item: 310, location: [957, 295]},
  {id: '54326a4b421aa90165001551', player_id: '52c64223761ba6e89f00001b', item: 308, location: [956, 295]},
  {id: '54326a4b421aa90165001552', player_id: '52c64223761ba6e89f00001b', item: 305, location: [955, 295]},
  {id: '54326a4b421aa90165001553', player_id: '52c64223761ba6e89f00001b', item: 310, location: [954, 295]},
  {id: '54326a4b421aa90165001554', player_id: '52c64223761ba6e89f00001b', item: 591, location: [946, 295]},
  {id: '54326a50421aa90165001557', player_id: '52c64223761ba6e89f00001b', item: 782, location: [945, 294]},
  {id: '54326a50421aa90165001558', player_id: '52c64223761ba6e89f00001b', item: 782, location: [947, 294]},
  {id: '54326a50421aa90165001559', player_id: '52c64223761ba6e89f00001b', item: 782, location: [948, 294]},
  {id: '54326a50421aa9016500155a', player_id: '52c64223761ba6e89f00001b', item: 1157, location: [946, 292]},
  {id: '54326a73421aa9016500156a', player_id: '51d3ee828e08fd5752000013', item: 855, location: [193, 112]},
  {id: '54326ab0421aa90165001590', player_id: '5251d49cf46fe5fe1700014d', item: 591, location: [945, 295]},
  {id: '54326ab5421aa90165001593', player_id: '5251d49cf46fe5fe1700014d', item: 756, location: [941, 291]},
  {id: '54326ab5421aa90165001594', player_id: '5251d49cf46fe5fe1700014d', item: 756, location: [939, 291]},
  {id: '54326ab5421aa90165001595', player_id: '5251d49cf46fe5fe1700014d', item: 756, location: [941, 289]},
  {id: '54326ab5421aa90165001596', player_id: '5251d49cf46fe5fe1700014d', item: 756, location: [939, 289]},
  {id: '54326ab5421aa90165001597', player_id: '5251d49cf46fe5fe1700014d', item: 756, location: [939, 293]},
  {id: '54326ac4421aa901650015a0', player_id: '5251d49cf46fe5fe1700014d', item: 764, location: [949, 288]},
  {id: '54326ac4421aa901650015a1', player_id: '5251d49cf46fe5fe1700014d', item: 764, location: [949, 287]},
  {id: '54326ac4421aa901650015a2', player_id: '5251d49cf46fe5fe1700014d', item: 764, location: [949, 286]},
  {id: '54326ac4421aa901650015a3', player_id: '5251d49cf46fe5fe1700014d', item: 764, location: [950, 286]},
  {id: '54326ac4421aa901650015a4', player_id: '5251d49cf46fe5fe1700014d', item: 764, location: [950, 287]},
  {id: '54326ac4421aa901650015a5', player_id: '5251d49cf46fe5fe1700014d', item: 764, location: [950, 288]},
  {id: '54326b66421aa901650015dc', player_id: '5130a6615109c0eafd00006e', item: 583, location: [945, 278]},
  {id: '54326b66421aa901650015dd', player_id: '5130a6615109c0eafd00006e', item: 583, location: [946, 278]},
  {id: '54326b6b421aa901650015e2', player_id: '5130a6615109c0eafd00006e', item: 580, location: [945, 279]},
  {id: '54326b6b421aa901650015e3', player_id: '5130a6615109c0eafd00006e', item: 581, location: [946, 280]},
  {id: '54326b75421aa901650015ec', player_id: '5130a6615109c0eafd00006e', item: 581, location: [947, 280]},
  {id: '54326b75421aa901650015ed', player_id: '5130a6615109c0eafd00006e', item: 580, location: [947, 281]},
  {id: '54326b75421aa901650015ee', player_id: '5130a6615109c0eafd00006e', item: 580, location: [947, 282]},
  {id: '54326b75421aa901650015ef', player_id: '5130a6615109c0eafd00006e', item: 580, location: [947, 283]},
  {id: '54326b75421aa901650015f0', player_id: '5130a6615109c0eafd00006e', item: 580, location: [947, 284]},
  {id: '54326b75421aa901650015f1', player_id: '5130a6615109c0eafd00006e', item: 760, location: [948, 288]},
  {id: '54326b7a421aa901650015f5', player_id: '5130a6615109c0eafd00006e', item: 1166, location: [946, 290]},
  {id: '54326b7a421aa901650015f6', player_id: '5130a6615109c0eafd00006e', item: 1162, location: [948, 292]},
  {id: '54326b84421aa901650015fd', player_id: '5130a6615109c0eafd00006e', item: 691, location: [953, 294]},
  {id: '54326b84421aa901650015fe', player_id: '5130a6615109c0eafd00006e', item: 691, location: [954, 294]},
  {id: '54326b84421aa901650015ff', player_id: '5130a6615109c0eafd00006e', item: 691, location: [954, 292]},
  {id: '54326b84421aa90165001600', player_id: '5130a6615109c0eafd00006e', item: 691, location: [954, 291]},
  {id: '54326b9e421aa9016500160e', player_id: '5130a6615109c0eafd00006e', item: 689, location: [958, 293]},
  {id: '54326ba3421aa90165001612', player_id: '5130a6615109c0eafd00006e', item: 689, location: [956, 293]},
  {id: '54326ba8421aa90165001617', player_id: '5130a6615109c0eafd00006e', item: 763, location: [941, 292]},
  {id: '54326bad421aa90165001619', player_id: '5130a6615109c0eafd00006e', item: 782, location: [942, 295]},
  {id: '54326bad421aa9016500161a', player_id: '5130a6615109c0eafd00006e', item: 798, location: [943, 292]},
  {id: '54326bad421aa9016500161b', player_id: '5130a6615109c0eafd00006e', item: 798, location: [943, 291]},
  {id: '54326bad421aa9016500161c', player_id: '5130a6615109c0eafd00006e', item: 798, location: [943, 290]},
  {id: '54326bb2421aa90165001621', player_id: '5130a6615109c0eafd00006e', item: 763, location: [942, 292]},
  {id: '54326bb2421aa90165001622', player_id: '5130a6615109c0eafd00006e', item: 798, location: [943, 293]},
  {id: '54326bb7421aa90165001624', player_id: '5130a6615109c0eafd00006e', item: 807, location: [946, 299]},
  {id: '54326bb7421aa90165001625', player_id: '5130a6615109c0eafd00006e', item: 807, location: [944, 301]},
  {id: '54326bbc421aa90165001628', player_id: '5130a6615109c0eafd00006e', item: 782, location: [962, 295]},
  {id: '54326bbc421aa90165001629', player_id: '5130a6615109c0eafd00006e', item: 605, location: [961, 293]},
  {id: '54326bbc421aa9016500162a', player_id: '5130a6615109c0eafd00006e', item: 605, location: [960, 293]},
  {id: '54326bbc421aa9016500162b', player_id: '5130a6615109c0eafd00006e', item: 606, location: [960, 292]},
  {id: '54326bbc421aa9016500162c', player_id: '5130a6615109c0eafd00006e', item: 606, location: [960, 291]},
  {id: '54326bc1421aa90165001631', player_id: '5130a6615109c0eafd00006e', item: 997, location: [958, 292]},
  {id: '54326bc1421aa90165001632', player_id: '5130a6615109c0eafd00006e', item: 997, location: [958, 291]},
  {id: '54326bc1421aa90165001633', player_id: '5130a6615109c0eafd00006e', item: 782, location: [957, 290]},
  {id: '54326bd6421aa90165001645', player_id: '5130a6615109c0eafd00006e', item: 584, location: [943, 286]},
  {id: '54326bdb421aa90165001649', player_id: '5130a6615109c0eafd00006e', item: 580, location: [944, 285]},
  {id: '54326bdb421aa9016500164a', player_id: '5130a6615109c0eafd00006e', item: 584, location: [944, 286]},
  {id: '54326bdb421aa9016500164b', player_id: '5130a6615109c0eafd00006e', item: 584, location: [943, 285]},
  {id: '54326bdb421aa9016500164c', player_id: '5130a6615109c0eafd00006e', item: 584, location: [942, 285]},
  {id: '54326bdb421aa9016500164d', player_id: '5130a6615109c0eafd00006e', item: 584, location: [942, 286]},
  {id: '54326bdb421aa9016500164e', player_id: '5130a6615109c0eafd00006e', item: 584, location: [941, 286]},
  {id: '54326bdb421aa9016500164f', player_id: '5130a6615109c0eafd00006e', item: 584, location: [941, 285]},
  {id: '54326be0421aa90165001652', player_id: '5130a6615109c0eafd00006e', item: 584, location: [939, 285]},
  {id: '54326be0421aa90165001653', player_id: '5130a6615109c0eafd00006e', item: 584, location: [939, 286]},
  {id: '54326be0421aa90165001654', player_id: '5130a6615109c0eafd00006e', item: 584, location: [943, 284]},
  {id: '54326be0421aa90165001655', player_id: '5130a6615109c0eafd00006e', item: 584, location: [943, 283]},
  {id: '54326be5421aa9016500165a', player_id: '5130a6615109c0eafd00006e', item: 584, location: [942, 284]},
  {id: '54326be5421aa9016500165b', player_id: '5130a6615109c0eafd00006e', item: 584, location: [943, 282]},
  {id: '54326bea421aa90165001660', player_id: '5130a6615109c0eafd00006e', item: 584, location: [943, 281]},
  {id: '54326bea421aa90165001661', player_id: '5130a6615109c0eafd00006e', item: 584, location: [942, 282]},
  {id: '54326bea421aa90165001662', player_id: '5130a6615109c0eafd00006e', item: 584, location: [942, 283]},
  {id: '54326bea421aa90165001663', player_id: '5130a6615109c0eafd00006e', item: 584, location: [941, 284]},
  {id: '54326bea421aa90165001664', player_id: '5130a6615109c0eafd00006e', item: 584, location: [941, 283]},
  {id: '54326bea421aa90165001665', player_id: '5130a6615109c0eafd00006e', item: 584, location: [942, 281]},
  {id: '54326bea421aa90165001666', player_id: '5130a6615109c0eafd00006e', item: 584, location: [941, 281]},
  {id: '54326bea421aa90165001667', player_id: '5130a6615109c0eafd00006e', item: 584, location: [941, 282]},
  {id: '54326bfe421aa90165001677', player_id: '5130a6615109c0eafd00006e', item: 1162, location: [948, 290]},
  {id: '54326c03421aa9016500167e', player_id: '5130a6615109c0eafd00006e', item: 1163, location: [945, 292]},
  {id: '54326c03421aa9016500167f', player_id: '5130a6615109c0eafd00006e', item: 1153, location: [945, 290]},
  {id: '54326c13421aa9016500168e', player_id: '5130a6615109c0eafd00006e', item: 997, location: [946, 293]},
  {id: '54326c13421aa9016500168f', player_id: '531b17bf45437518eb000031', item: 853, location: [835, 477]},
  {id: '54326c1d421aa90165001698', player_id: '5130a6615109c0eafd00006e', item: 781, location: [949, 292]},
  {id: '54326c31421aa901650016a6', player_id: '5130a6615109c0eafd00006e', item: 580, location: [955, 284]},
  {id: '54326c31421aa901650016a7', player_id: '5130a6615109c0eafd00006e', item: 580, location: [955, 283]},
  {id: '54326c31421aa901650016a8', player_id: '5130a6615109c0eafd00006e', item: 580, location: [955, 282]},
  {id: '54326c31421aa901650016a9', player_id: '5130a6615109c0eafd00006e', item: 580, location: [955, 281]},
  {id: '54326c31421aa901650016aa', player_id: '5130a6615109c0eafd00006e', item: 581, location: [955, 280]},
  {id: '54326c31421aa901650016ab', player_id: '5130a6615109c0eafd00006e', item: 583, location: [955, 278]},
  {id: '54326c36421aa901650016ad', player_id: '5130a6615109c0eafd00006e', item: 580, location: [954, 282]},
  {id: '54326c36421aa901650016ae', player_id: '5130a6615109c0eafd00006e', item: 580, location: [954, 283]},
  {id: '54326c36421aa901650016af', player_id: '5130a6615109c0eafd00006e', item: 580, location: [953, 284]},
  {id: '54326c36421aa901650016b0', player_id: '5130a6615109c0eafd00006e', item: 580, location: [954, 281]},
  {id: '54326c36421aa901650016b1', player_id: '5130a6615109c0eafd00006e', item: 580, location: [953, 282]},
  {id: '54326c3b421aa901650016b5', player_id: '5130a6615109c0eafd00006e', item: 580, location: [953, 283]},
  {id: '54326c3b421aa901650016b6', player_id: '5130a6615109c0eafd00006e', item: 580, location: [953, 280]},
  {id: '54326c3b421aa901650016b7', player_id: '5130a6615109c0eafd00006e', item: 580, location: [954, 280]},
  {id: '54326c3b421aa901650016b8', player_id: '5130a6615109c0eafd00006e', item: 580, location: [953, 281]},
  {id: '54326c3b421aa901650016b9', player_id: '5130a6615109c0eafd00006e', item: 580, location: [953, 279]},
  {id: '54326c3b421aa901650016ba', player_id: '5130a6615109c0eafd00006e', item: 581, location: [953, 278]},
  {id: '54326c3b421aa901650016bb', player_id: '5130a6615109c0eafd00006e', item: 581, location: [952, 278]},
  {id: '54326c55421aa901650016d1', player_id: '5130a6615109c0eafd00006e', item: 764, location: [950, 285]},
  {id: '54326c5a421aa901650016d7', player_id: '5130a6615109c0eafd00006e', item: 580, location: [948, 284]},
  {id: '54326c5a421aa901650016d8', player_id: '5130a6615109c0eafd00006e', item: 755, location: [946, 286]},
  {id: '54326c5a421aa901650016d9', player_id: '5130a6615109c0eafd00006e', item: 580, location: [946, 283]},
  {id: '54326c5a421aa901650016da', player_id: '5130a6615109c0eafd00006e', item: 580, location: [946, 282]},
  {id: '54326c5a421aa901650016db', player_id: '5130a6615109c0eafd00006e', item: 580, location: [946, 281]},
  {id: '54326c5a421aa901650016dc', player_id: '5130a6615109c0eafd00006e', item: 580, location: [945, 280]},
  {id: '54326c5a421aa901650016dd', player_id: '5130a6615109c0eafd00006e', item: 580, location: [945, 281]},
  {id: '54326c5f421aa901650016e3', player_id: '5130a6615109c0eafd00006e', item: 580, location: [945, 282]},
  {id: '54326c5f421aa901650016e4', player_id: '5130a6615109c0eafd00006e', item: 580, location: [945, 284]},
  {id: '54326c5f421aa901650016e5', player_id: '5130a6615109c0eafd00006e', item: 580, location: [945, 283]},
  {id: '54326c64421aa901650016e9', player_id: '5130a6615109c0eafd00006e', item: 580, location: [946, 284]},
  {id: '54326c69421aa901650016ef', player_id: '5130a6615109c0eafd00006e', item: 580, location: [951, 281]},
  {id: '54326c69421aa901650016f0', player_id: '5130a6615109c0eafd00006e', item: 580, location: [951, 280]},
  {id: '54326c69421aa901650016f1', player_id: '5130a6615109c0eafd00006e', item: 580, location: [951, 279]},
  {id: '54326c69421aa901650016f2', player_id: '5130a6615109c0eafd00006e', item: 581, location: [951, 278]},
  {id: '54326c69421aa901650016f3', player_id: '5130a6615109c0eafd00006e', item: 583, location: [951, 276]},
  {id: '54326c6e421aa901650016f5', player_id: '5130a6615109c0eafd00006e', item: 583, location: [952, 276]},
  {id: '54326c6e421aa901650016f6', player_id: '5130a6615109c0eafd00006e', item: 583, location: [953, 276]},
  {id: '54326c6e421aa901650016f7', player_id: '5130a6615109c0eafd00006e', item: 583, location: [954, 277]},
  {id: '54326c6e421aa901650016f8', player_id: '5130a6615109c0eafd00006e', item: 581, location: [954, 279]},
  {id: '54326c78421aa901650016fd', player_id: '5130a6615109c0eafd00006e', item: 606, location: [960, 290]},
  {id: '54326c78421aa901650016fe', player_id: '5130a6615109c0eafd00006e', item: 604, location: [960, 289]},
  {id: '54326c78421aa901650016ff', player_id: '5130a6615109c0eafd00006e', item: 604, location: [961, 288]},
  {id: '54326c78421aa90165001700', player_id: '5130a6615109c0eafd00006e', item: 604, location: [961, 289]},
  {id: '54326c78421aa90165001701', player_id: '5130a6615109c0eafd00006e', item: 604, location: [962, 288]},
  {id: '54326c78421aa90165001702', player_id: '5130a6615109c0eafd00006e', item: 604, location: [960, 288]},
  {id: '54326c7d421aa90165001705', player_id: '5130a6615109c0eafd00006e', item: 604, location: [962, 289]},
  {id: '54326c7d421aa90165001706', player_id: '5130a6615109c0eafd00006e', item: 604, location: [963, 289]},
  {id: '54326c7d421aa90165001707', player_id: '5130a6615109c0eafd00006e', item: 604, location: [964, 289]},
  {id: '54326c7d421aa90165001708', player_id: '5130a6615109c0eafd00006e', item: 604, location: [963, 288]},
  {id: '54326c7d421aa90165001709', player_id: '5130a6615109c0eafd00006e', item: 604, location: [964, 288]},
  {id: '54326c7d421aa9016500170a', player_id: '5130a6615109c0eafd00006e', item: 606, location: [962, 290]},
  {id: '54326c82421aa90165001711', player_id: '5130a6615109c0eafd00006e', item: 606, location: [964, 290]},
  {id: '54326c82421aa90165001712', player_id: '5130a6615109c0eafd00006e', item: 606, location: [961, 290]},
  {id: '54326c82421aa90165001713', player_id: '5130a6615109c0eafd00006e', item: 606, location: [962, 291]},
  {id: '54326c82421aa90165001714', player_id: '5130a6615109c0eafd00006e', item: 606, location: [963, 291]},
  {id: '54326c82421aa90165001715', player_id: '5130a6615109c0eafd00006e', item: 606, location: [962, 292]},
  {id: '54326c82421aa90165001716', player_id: '5130a6615109c0eafd00006e', item: 606, location: [961, 292]},
  {id: '54326c82421aa90165001717', player_id: '5130a6615109c0eafd00006e', item: 606, location: [961, 291]},
  {id: '54326c82421aa90165001718', player_id: '5130a6615109c0eafd00006e', item: 606, location: [963, 292]},
  {id: '54326c82421aa90165001719', player_id: '5130a6615109c0eafd00006e', item: 606, location: [964, 291]},
  {id: '54326c82421aa9016500171a', player_id: '5130a6615109c0eafd00006e', item: 606, location: [963, 290]},
  {id: '54326c87421aa9016500171c', player_id: '5130a6615109c0eafd00006e', item: 605, location: [963, 293]},
  {id: '54326c87421aa9016500171d', player_id: '5130a6615109c0eafd00006e', item: 605, location: [964, 293]},
  {id: '54326c87421aa9016500171e', player_id: '5130a6615109c0eafd00006e', item: 606, location: [964, 292]},
  {id: '54326c87421aa9016500171f', player_id: '5130a6615109c0eafd00006e', item: 605, location: [962, 293]},
  {id: '54326c8c421aa90165001721', player_id: '51d3ee828e08fd5752000013', item: 854, location: [1747, 53]},
  {id: '54326cab421aa90165001736', player_id: '5130a6615109c0eafd00006e', item: 782, location: [941, 295]},
  {id: '54326cab421aa90165001737', player_id: '5130a6615109c0eafd00006e', item: 782, location: [940, 295]},
  {id: '54326cb0421aa9016500173a', player_id: '5130a6615109c0eafd00006e', item: 580, location: [949, 284]},
  {id: '54326cb0421aa9016500173b', player_id: '5130a6615109c0eafd00006e', item: 580, location: [949, 283]},
  {id: '54326cb0421aa9016500173c', player_id: '5130a6615109c0eafd00006e', item: 580, location: [949, 282]},
  {id: '54326cb0421aa9016500173d', player_id: '5130a6615109c0eafd00006e', item: 580, location: [949, 281]},
  {id: '54326cb5421aa9016500173f', player_id: '5130a6615109c0eafd00006e', item: 580, location: [949, 280]},
  {id: '54326cb5421aa90165001740', player_id: '5130a6615109c0eafd00006e', item: 581, location: [949, 279]},
  {id: '54326cb5421aa90165001741', player_id: '5130a6615109c0eafd00006e', item: 583, location: [949, 277]},
  {id: '54326cb5421aa90165001742', player_id: '5130a6615109c0eafd00006e', item: 583, location: [948, 278]},
  {id: '54326cb5421aa90165001743', player_id: '5130a6615109c0eafd00006e', item: 583, location: [947, 278]},
  {id: '54326cb5421aa90165001744', player_id: '5130a6615109c0eafd00006e', item: 581, location: [950, 278]},
  {id: '54326cba421aa90165001749', player_id: '5130a6615109c0eafd00006e', item: 583, location: [950, 276]},
  {id: '54326cbf421aa9016500174e', player_id: '5130a6615109c0eafd00006e', item: 585, location: [958, 285]},
  {id: '54326cbf421aa9016500174f', player_id: '5130a6615109c0eafd00006e', item: 585, location: [959, 285]},
  {id: '54326cbf421aa90165001750', player_id: '5130a6615109c0eafd00006e', item: 585, location: [959, 286]},
  {id: '54326cc4421aa90165001752', player_id: '5130a6615109c0eafd00006e', item: 585, location: [958, 286]},
  {id: '54326cc4421aa90165001753', player_id: '5130a6615109c0eafd00006e', item: 585, location: [960, 285]},
  {id: '54326cc4421aa90165001754', player_id: '5130a6615109c0eafd00006e', item: 585, location: [960, 286]},
  {id: '54326cc4421aa90165001755', player_id: '5130a6615109c0eafd00006e', item: 585, location: [961, 286]},
  {id: '54326cc4421aa90165001756', player_id: '5130a6615109c0eafd00006e', item: 585, location: [961, 285]},
  {id: '54326cc4421aa90165001757', player_id: '5130a6615109c0eafd00006e', item: 585, location: [962, 285]},
  {id: '54326cc9421aa9016500175a', player_id: '5130a6615109c0eafd00006e', item: 585, location: [962, 286]},
  {id: '54326cc9421aa9016500175b', player_id: '5130a6615109c0eafd00006e', item: 585, location: [964, 285]},
  {id: '54326cc9421aa9016500175c', player_id: '5130a6615109c0eafd00006e', item: 585, location: [964, 286]},
  {id: '54326cc9421aa9016500175d', player_id: '5130a6615109c0eafd00006e', item: 585, location: [962, 284]},
  {id: '54326cc9421aa9016500175e', player_id: '5130a6615109c0eafd00006e', item: 585, location: [961, 283]},
  {id: '54326cc9421aa9016500175f', player_id: '5130a6615109c0eafd00006e', item: 585, location: [962, 283]},
  {id: '54326cc9421aa90165001760', player_id: '5130a6615109c0eafd00006e', item: 585, location: [962, 282]},
  {id: '54326cc9421aa90165001761', player_id: '5130a6615109c0eafd00006e', item: 585, location: [961, 282]},
  {id: '54326cc9421aa90165001762', player_id: '51d3ee828e08fd5752000013', item: 854, location: [1768, 54]},
  {id: '54326cc9421aa90165001763', player_id: '5130a6615109c0eafd00006e', item: 585, location: [960, 283]},
  {id: '54326cc9421aa90165001764', player_id: '5130a6615109c0eafd00006e', item: 585, location: [960, 282]},
  {id: '54326cce421aa90165001765', player_id: '5130a6615109c0eafd00006e', item: 585, location: [961, 281]},
  {id: '54326cce421aa90165001766', player_id: '5130a6615109c0eafd00006e', item: 585, location: [962, 281]},
  {id: '54326cce421aa90165001767', player_id: '5130a6615109c0eafd00006e', item: 585, location: [960, 281]},
  {id: '54326cce421aa90165001768', player_id: '5130a6615109c0eafd00006e', item: 585, location: [960, 284]},
  {id: '54326cce421aa90165001769', player_id: '5130a6615109c0eafd00006e', item: 585, location: [961, 284]},
  {id: '54326cd3421aa9016500176d', player_id: '5130a6615109c0eafd00006e', item: 580, location: [958, 284]},
  {id: '54326cd8421aa9016500176e', player_id: '5130a6615109c0eafd00006e', item: 580, location: [957, 284]},
  {id: '54326cd8421aa9016500176f', player_id: '5130a6615109c0eafd00006e', item: 580, location: [957, 283]},
  {id: '54326cd8421aa90165001770', player_id: '5130a6615109c0eafd00006e', item: 580, location: [957, 282]},
  {id: '54326cd8421aa90165001771', player_id: '5130a6615109c0eafd00006e', item: 580, location: [957, 281]},
  {id: '54326cd8421aa90165001772', player_id: '5130a6615109c0eafd00006e', item: 581, location: [957, 280]},
  {id: '54326cd8421aa90165001773', player_id: '5130a6615109c0eafd00006e', item: 583, location: [957, 278]},
  {id: '54326cd8421aa90165001774', player_id: '5130a6615109c0eafd00006e', item: 583, location: [956, 278]},
  {id: '54326cd8421aa90165001775', player_id: '5130a6615109c0eafd00006e', item: 583, location: [958, 278]},
  {id: '54326cd8421aa90165001776', player_id: '5130a6615109c0eafd00006e', item: 580, location: [958, 281]},
  {id: '54326cd8421aa90165001777', player_id: '5130a6615109c0eafd00006e', item: 580, location: [956, 283]},
  {id: '54326cd8421aa90165001778', player_id: '5130a6615109c0eafd00006e', item: 580, location: [956, 282]},
  {id: '54326cd8421aa90165001779', player_id: '5130a6615109c0eafd00006e', item: 580, location: [956, 281]},
  {id: '54326cdd421aa9016500177c', player_id: '5130a6615109c0eafd00006e', item: 581, location: [956, 280]},
  {id: '54326cdd421aa9016500177d', player_id: '5130a6615109c0eafd00006e', item: 580, location: [956, 284]},
  {id: '54326cdd421aa9016500177e', player_id: '5130a6615109c0eafd00006e', item: 580, location: [958, 282]},
  {id: '54326cdd421aa9016500177f', player_id: '5130a6615109c0eafd00006e', item: 580, location: [958, 280]},
  {id: '54326cdd421aa90165001780', player_id: '5130a6615109c0eafd00006e', item: 580, location: [958, 279]},
  {id: '54326cdd421aa90165001781', player_id: '5130a6615109c0eafd00006e', item: 580, location: [958, 283]},
  {id: '54326ce2421aa90165001784', player_id: '5130a6615109c0eafd00006e', item: 754, location: [953, 287]},
  {id: '54326ce8421aa90165001786', player_id: '5130a6615109c0eafd00006e', item: 754, location: [954, 287]},
  {id: '54326ce8421aa90165001787', player_id: '5130a6615109c0eafd00006e', item: 782, location: [953, 286]},
  {id: '54326ce8421aa90165001788', player_id: '5130a6615109c0eafd00006e', item: 580, location: [954, 284]},
  {id: '54326ce8421aa90165001789', player_id: '5130a6615109c0eafd00006e', item: 754, location: [955, 285]},
  {id: '54326ce8421aa9016500178a', player_id: '5130a6615109c0eafd00006e', item: 754, location: [955, 287]},
  {id: '54326ce8421aa9016500178b', player_id: '5130a6615109c0eafd00006e', item: 919, location: [953, 290]},
  {id: '54326ce8421aa9016500178c', player_id: '5130a6615109c0eafd00006e', item: 754, location: [956, 287]},
  {id: '54326cf2421aa9016500178f', player_id: '531b17bf45437518eb000031', item: 581, location: [733, 450]},
  {id: '54326cf2421aa90165001790', player_id: '531b17bf45437518eb000031', item: 695, location: [734, 449]},
  {id: '54326cf2421aa90165001791', player_id: '531b17bf45437518eb000031', item: 697, location: [735, 449]},
  {id: '54326cf2421aa90165001792', player_id: '5130a6615109c0eafd00006e', item: 580, location: [950, 284]},
  {id: '54326cf7421aa90165001794', player_id: '5130a6615109c0eafd00006e', item: 580, location: [950, 283]},
  {id: '54326cf7421aa90165001795', player_id: '5130a6615109c0eafd00006e', item: 580, location: [950, 282]},
  {id: '54326cf7421aa90165001796', player_id: '5130a6615109c0eafd00006e', item: 580, location: [950, 281]},
  {id: '54326cf7421aa90165001797', player_id: '5130a6615109c0eafd00006e', item: 580, location: [950, 280]},
  {id: '54326cf7421aa90165001798', player_id: '5130a6615109c0eafd00006e', item: 580, location: [950, 279]},
  {id: '54326cf7421aa90165001799', player_id: '5130a6615109c0eafd00006e', item: 580, location: [948, 281]},
  {id: '54326cf7421aa9016500179a', player_id: '5130a6615109c0eafd00006e', item: 581, location: [948, 280]},
  {id: '54326cf7421aa9016500179b', player_id: '5130a6615109c0eafd00006e', item: 580, location: [948, 282]},
  {id: '54326cf7421aa9016500179c', player_id: '5130a6615109c0eafd00006e', item: 580, location: [948, 283]},
  {id: '54326cf7421aa9016500179d', player_id: '5130a6615109c0eafd00006e', item: 580, location: [952, 279]},
  {id: '54326cf7421aa9016500179e', player_id: '5130a6615109c0eafd00006e', item: 580, location: [952, 281]},
  {id: '54326cfc421aa901650017a0', player_id: '5130a6615109c0eafd00006e', item: 580, location: [952, 280]},
  {id: '54326d01421aa901650017a2', player_id: '51d3ee828e08fd5752000013', item: 849, location: [1770, 60]},
  {id: '54326d06421aa901650017a5', player_id: '531b17bf45437518eb000031', item: 933, location: [732, 447]},
  {id: '54326d0b421aa901650017a7', player_id: '531b17bf45437518eb000031', item: 604, location: [734, 452]},
  {id: '54326d0b421aa901650017a8', player_id: '531b17bf45437518eb000031', item: 606, location: [735, 452]},
  {id: '54326d0b421aa901650017a9', player_id: '531b17bf45437518eb000031', item: 605, location: [736, 452]},
  {id: '54326d0b421aa901650017aa', player_id: '5130a6615109c0eafd00006e', item: 913, location: [955, 303]},
  {id: '54326d0b421aa901650017ab', player_id: '531b17bf45437518eb000031', item: 751, location: [738, 449]},
  {id: '54326d0b421aa901650017ac', player_id: '5130a6615109c0eafd00006e', item: 910, location: [951, 299]},
  {id: '54326d10421aa901650017af', player_id: '531b17bf45437518eb000031', item: 696, location: [736, 449]},
  {id: '54326d10421aa901650017b0', player_id: '531b17bf45437518eb000031', item: 798, location: [737, 450]},
  {id: '54326d15421aa901650017b3', player_id: '531b17bf45437518eb000031', item: 794, location: [735, 451]},
  {id: '54326d15421aa901650017b4', player_id: '531b17bf45437518eb000031', item: 849, location: [735, 448]},
  {id: '54326d15421aa901650017b5', player_id: '531b17bf45437518eb000031', item: 831, location: [737, 449]},
  {id: '54326d84421aa901650017df', player_id: '5187c45ef4cdc4653a000061', item: 676, location: [814, 138]},
  {id: '54326db7421aa901650017f1', player_id: '5187c45ef4cdc4653a000061', item: 676, location: [809, 138]},
  {id: '54326db7421aa901650017f2', player_id: '5187c45ef4cdc4653a000061', item: 780, location: [809, 136]},
  {id: '54326dbc421aa901650017f5', player_id: '5370ca714504d33a75000081', item: 694, location: [1176, 73]},
  {id: '54326dbc421aa901650017f7', player_id: '5370ca714504d33a75000081', item: 861, location: [1176, 77]},
  {id: '54326dd5421aa90165001802', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [825, 266]},
  {id: '54326dd5421aa90165001803', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [825, 264]},
  {id: '54326dd5421aa90165001804', player_id: '5187c45ef4cdc4653a000061', item: 766, location: [826, 262]},
  {id: '54326dd5421aa90165001805', player_id: '5187c45ef4cdc4653a000061', item: 797, location: [828, 262]},
  {id: '54326dd5421aa90165001806', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [829, 264]},
  {id: '54326dd5421aa90165001807', player_id: '5187c45ef4cdc4653a000061', item: 756, location: [833, 264]},
  {id: '54326dd5421aa90165001808', player_id: '5187c45ef4cdc4653a000061', item: 756, location: [835, 264]},
  {id: '54326dd5421aa90165001809', player_id: '5187c45ef4cdc4653a000061', item: 756, location: [837, 264]},
  {id: '54326dd5421aa9016500180a', player_id: '5187c45ef4cdc4653a000061', item: 756, location: [839, 264]},
  {id: '54326dd5421aa9016500180b', player_id: '5187c45ef4cdc4653a000061', item: 756, location: [841, 264]},
  {id: '54326de0421aa9016500180f', player_id: '5187c45ef4cdc4653a000061', item: 755, location: [837, 275]},
  {id: '54326de5421aa90165001812', player_id: '5187c45ef4cdc4653a000061', item: 754, location: [836, 275]},
  {id: '54326de5421aa90165001813', player_id: '5187c45ef4cdc4653a000061', item: 754, location: [839, 275]},
  {id: '54326de5421aa90165001814', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [839, 266]},
  {id: '54326de5421aa90165001815', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [841, 266]},
  {id: '54326de5421aa90165001816', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [840, 262]},
  {id: '54326de5421aa90165001817', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [838, 262]},
  {id: '54326de5421aa90165001818', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [836, 262]},
  {id: '54326de5421aa90165001819', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [834, 262]},
  {id: '54326de5421aa9016500181a', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [832, 262]},
  {id: '54326de5421aa9016500181b', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [830, 262]},
  {id: '54326dea421aa9016500181d', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [824, 262]},
  {id: '54326dea421aa9016500181e', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [827, 266]},
  {id: '54326dea421aa9016500181f', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [827, 264]},
  {id: '54326dea421aa90165001820', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [829, 266]},
  {id: '54326dea421aa90165001821', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [831, 266]},
  {id: '54326dea421aa90165001822', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [831, 264]},
  {id: '54326dea421aa90165001823', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [833, 266]},
  {id: '54326dea421aa90165001824', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [835, 266]},
  {id: '54326dea421aa90165001825', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [837, 266]},
  {id: '54326dea421aa90165001826', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [832, 271]},
  {id: '54326dea421aa90165001827', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [830, 271]},
  {id: '54326dea421aa90165001828', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [828, 271]},
  {id: '54326def421aa9016500182a', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [826, 271]},
  {id: '54326def421aa9016500182b', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [824, 271]},
  {id: '54326def421aa9016500182c', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [824, 269]},
  {id: '54326def421aa9016500182d', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [826, 269]},
  {id: '54326def421aa9016500182e', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [828, 269]},
  {id: '54326def421aa9016500182f', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [830, 269]},
  {id: '54326def421aa90165001830', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [832, 269]},
  {id: '54326e13421aa9016500183b', player_id: '5187c45ef4cdc4653a000061', item: 854, location: [834, 269]},
  {id: '54326e18421aa9016500183f', player_id: '51d3ee828e08fd5752000013', item: 849, location: [1841, 57]},
  {id: '54326e69421aa90165001868', player_id: '5130a6615109c0eafd00006e', item: 913, location: [950, 301]},
  {id: '54326e69421aa90165001869', player_id: '531b17bf45437518eb000031', item: 855, location: [834, 452]},
  {id: '54326e88421aa90165001876', player_id: '5227db5baeac1d7d6c0000c0', item: 919, location: [1153, 117]},
  {id: '54326e8d421aa90165001877', player_id: '537e80d6d968534b59000036', item: 853, location: [1815, 446]},
  {id: '54326e8d421aa90165001878', player_id: '531b17bf45437518eb000031', item: 916, location: [838, 504]},
  {id: '54326ea2421aa9016500187f', player_id: '537e80d6d968534b59000036', item: 854, location: [1823, 436]},
  {id: '54326f11421aa901650018ac', player_id: '531b17bf45437518eb000031', item: 855, location: [778, 597]},
  {id: '54326f16421aa901650018ad', player_id: '5370ca714504d33a75000081', item: 694, location: [1176, 71]},
  {id: '54326f1c421aa901650018ae', player_id: '5370ca714504d33a75000081', item: 861, location: [1175, 75]},
  {id: '54326f45421aa901650018bc', player_id: '531b17bf45437518eb000031', item: 849, location: [713, 597]},
  {id: '54326f4f421aa901650018be', player_id: '5187c45ef4cdc4653a000061', item: 913, location: [1089, 537]},
  {id: '54326f54421aa901650018c0', player_id: '5187c45ef4cdc4653a000061', item: 1008, location: [1079, 536]},
  {id: '54326f54421aa901650018c1', player_id: '5187c45ef4cdc4653a000061', item: 913, location: [1078, 529]},
  {id: '54326f54421aa901650018c2', player_id: '5187c45ef4cdc4653a000061', item: 1105, location: [1078, 530]},
  {id: '54326f59421aa901650018c5', player_id: '537e80d6d968534b59000036', item: 782, location: [689, 308]},
  {id: '54326f5e421aa901650018c6', player_id: '5187c45ef4cdc4653a000061', item: 637, location: [1079, 539]},
  {id: '54326f5e421aa901650018c7', player_id: '537e80d6d968534b59000036', item: 965, location: [689, 307]},
  {id: '54326f5e421aa901650018c8', player_id: '537e80d6d968534b59000036', item: 966, location: [693, 309]},
  {id: '54326f5e421aa901650018c9', player_id: '5187c45ef4cdc4653a000061', item: 796, location: [1079, 538]},
  {id: '54326f5e421aa901650018ca', player_id: '537e80d6d968534b59000036', item: 965, location: [691, 307]},
  {id: '54326f5e421aa901650018cb', player_id: '537e80d6d968534b59000036', item: 798, location: [693, 306]},
  {id: '54326f5e421aa901650018cc', player_id: '537e80d6d968534b59000036', item: 965, location: [694, 307]},
  {id: '54326f63421aa901650018ce', player_id: '537e80d6d968534b59000036', item: 782, location: [696, 308]},
  {id: '54326f63421aa901650018cf', player_id: '537e80d6d968534b59000036', item: 965, location: [697, 307]},
  {id: '54326f63421aa901650018d0', player_id: '537e80d6d968534b59000036', item: 965, location: [696, 307]},
  {id: '54326f63421aa901650018d1', player_id: '537e80d6d968534b59000036', item: 965, location: [698, 308]},
  {id: '54326f63421aa901650018d2', player_id: '537e80d6d968534b59000036', item: 604, location: [697, 310]},
  {id: '54326f68421aa901650018d6', player_id: '537e80d6d968534b59000036', item: 966, location: [692, 313]},
  {id: '54326f68421aa901650018d7', player_id: '537e80d6d968534b59000036', item: 604, location: [690, 310]},
  {id: '54326f68421aa901650018d8', player_id: '537e80d6d968534b59000036', item: 966, location: [692, 309]},
  {id: '54326f68421aa901650018d9', player_id: '537e80d6d968534b59000036', item: 966, location: [694, 309]},
  {id: '54326f68421aa901650018da', player_id: '537e80d6d968534b59000036', item: 966, location: [693, 311]},
  {id: '54326f68421aa901650018db', player_id: '537e80d6d968534b59000036', item: 754, location: [693, 313]},
  {id: '54326f6d421aa901650018dd', player_id: '537e80d6d968534b59000036', item: 966, location: [693, 315]},
  {id: '54326f6d421aa901650018de', player_id: '537e80d6d968534b59000036', item: 966, location: [694, 315]},
  {id: '54326f6d421aa901650018df', player_id: '537e80d6d968534b59000036', item: 966, location: [691, 315]},
  {id: '54326f6d421aa901650018e0', player_id: '537e80d6d968534b59000036', item: 966, location: [690, 315]},
  {id: '54326f6d421aa901650018e1', player_id: '537e80d6d968534b59000036', item: 785, location: [689, 313]},
  {id: '54326f6d421aa901650018e2', player_id: '537e80d6d968534b59000036', item: 966, location: [691, 313]},
  {id: '54326f72421aa901650018e4', player_id: '537e80d6d968534b59000036', item: 966, location: [692, 315]},
  {id: '54326f72421aa901650018e5', player_id: '537e80d6d968534b59000036', item: 785, location: [697, 313]},
  {id: '54326f72421aa901650018e6', player_id: '537e80d6d968534b59000036', item: 965, location: [697, 315]},
  {id: '54326f72421aa901650018e7', player_id: '537e80d6d968534b59000036', item: 965, location: [698, 314]},
  {id: '54326f77421aa901650018e9', player_id: '537e80d6d968534b59000036', item: 797, location: [697, 323]},
  {id: '54326f77421aa901650018ea', player_id: '537e80d6d968534b59000036', item: 967, location: [695, 324]},
  {id: '54326f77421aa901650018eb', player_id: '537e80d6d968534b59000036', item: 967, location: [695, 325]},
  {id: '54326f77421aa901650018ec', player_id: '537e80d6d968534b59000036', item: 807, location: [696, 327]},
  {id: '54326f7c421aa901650018f1', player_id: '537e80d6d968534b59000036', item: 807, location: [688, 327]},
  {id: '54326f7c421aa901650018f2', player_id: '537e80d6d968534b59000036', item: 797, location: [689, 323]},
  {id: '54326f7c421aa901650018f3', player_id: '537e80d6d968534b59000036', item: 639, location: [686, 323]},
  {id: '54326f82421aa901650018f4', player_id: '537e80d6d968534b59000036', item: 742, location: [695, 322]},
  {id: '54326f82421aa901650018f5', player_id: '537e80d6d968534b59000036', item: 742, location: [696, 321]},
  {id: '54326f87421aa901650018f6', player_id: '537e80d6d968534b59000036', item: 797, location: [695, 318]},
  {id: '54326f96421aa901650018f9', player_id: '5187c45ef4cdc4653a000061', item: 832, location: [971, 278]},
  {id: '54326f96421aa901650018fa', player_id: '5187c45ef4cdc4653a000061', item: 797, location: [971, 276]},
  {id: '54326f96421aa901650018fb', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [974, 276]},
  {id: '54326f9b421aa901650018ff', player_id: '5187c45ef4cdc4653a000061', item: 797, location: [978, 276]},
  {id: '54326fa5421aa90165001901', player_id: '5187c45ef4cdc4653a000061', item: 854, location: [978, 268]},
  {id: '5432718d421aa901650019f4', player_id: '51d3ee828e08fd5752000013', item: 854, location: [1148, 589]},
  {id: '543271b6421aa90165001a0f', player_id: '5313692ad9045f2a75000064', item: 508, location: [1181, 82]},
  {id: '543271d4421aa90165001a1f', player_id: '50f3d041a979b30d0000002b', item: 508, location: [1182, 83]},
  {id: '543271e9421aa90165001a2f', player_id: '5227db5baeac1d7d6c0000c0', item: 508, location: [1182, 82]},
  {id: '543271ee421aa90165001a34', player_id: '531b17bf45437518eb000031', item: 855, location: [778, 598]},
  {id: '54327207421aa90165001a4f', player_id: '531b17bf45437518eb000031', item: 855, location: [777, 598]},
  {id: '54327258421aa90165001a85', player_id: '5370ca714504d33a75000081', item: 861, location: [1175, 75]},
  {id: '543272d1421aa90165001ac4', player_id: '5187c45ef4cdc4653a000061', item: 849, location: [1120, 224]},
  {id: '543272d6421aa90165001ac7', player_id: '5187c45ef4cdc4653a000061', item: 849, location: [1114, 222]},
  {id: '543272db421aa90165001acd', player_id: '5187c45ef4cdc4653a000061', item: 849, location: [1108, 223]},
  {id: '543272e6421aa90165001ad2', player_id: '527cdb0c9b57e053e5000061', item: 680, location: [1156, 120]},
  {id: '54327350421aa90165001b12', player_id: '5187c45ef4cdc4653a000061', item: 930, location: [1401, 440]},
  {id: '54327369421aa90165001b22', player_id: '5187c45ef4cdc4653a000061', item: 855, location: [1394, 440]},
  {id: '543273f7421aa90165001b5e', player_id: '5187c45ef4cdc4653a000061', item: 780, location: [1806, 579]},
  {id: '543273fc421aa90165001b61', player_id: '5187c45ef4cdc4653a000061', item: 850, location: [1808, 573]},
  {id: '54327401421aa90165001b67', player_id: '5187c45ef4cdc4653a000061', item: 780, location: [1834, 595]},
  {id: '54327401421aa90165001b68', player_id: '5187c45ef4cdc4653a000061', item: 797, location: [1831, 595]},
  {id: '54327401421aa90165001b69', player_id: '5187c45ef4cdc4653a000061', item: 785, location: [1836, 595]},
  {id: '54327406421aa90165001b6d', player_id: '5187c45ef4cdc4653a000061', item: 854, location: [1834, 592]},
  {id: '54327442421aa90165001b7b', player_id: '5227db5baeac1d7d6c0000c0', item: 690, location: [1153, 122]},
  {id: '54327484421aa90165001b90', player_id: '5187c45ef4cdc4653a000061', item: 855, location: [1875, 429]},
  {id: '5432748e421aa90165001b92', player_id: '5187c45ef4cdc4653a000061', item: 797, location: [1876, 388]},
  {id: '5432748e421aa90165001b93', player_id: '5187c45ef4cdc4653a000061', item: 807, location: [1872, 388]},
  {id: '54327498421aa90165001b95', player_id: '5187c45ef4cdc4653a000061', item: 855, location: [1876, 369]},
  {id: '543274a2421aa90165001b98', player_id: '5187c45ef4cdc4653a000061', item: 792, location: [1870, 359]},
  {id: '54327576421aa90165001bd4', player_id: '5370ca714504d33a75000081', item: 913, location: [1230, 73]},
  {id: '543275e5421aa90165001c08', player_id: '5412826dd74141ec3d000154', item: 756, location: [1187, 157]},
  {id: '543275ea421aa90165001c0d', player_id: '5412826dd74141ec3d000154', item: 756, location: [1194, 157]},
  {id: '54327603421aa90165001c15', player_id: '5412826dd74141ec3d000154', item: 910, location: [1190, 156]},
  {id: '543277c0421aa90165001cd9', player_id: '5370ca714504d33a75000081', item: 585, location: [1229, 66]},
  {id: '543277c0421aa90165001cda', player_id: '5370ca714504d33a75000081', item: 580, location: [1230, 67]},
  {id: '543277c0421aa90165001cdb', player_id: '5370ca714504d33a75000081', item: 580, location: [1230, 68]},
  {id: '543277c6421aa90165001cdd', player_id: '5370ca714504d33a75000081', item: 580, location: [1230, 66]},
  {id: '543277c6421aa90165001cde', player_id: '5370ca714504d33a75000081', item: 580, location: [1231, 68]},
  {id: '543277c6421aa90165001cdf', player_id: '5370ca714504d33a75000081', item: 581, location: [1231, 70]},
  {id: '543277c6421aa90165001ce0', player_id: '5370ca714504d33a75000081', item: 580, location: [1231, 71]},
  {id: '543277c6421aa90165001ce1', player_id: '5370ca714504d33a75000081', item: 580, location: [1231, 67]},
  {id: '54327984421aa90165001d7f', player_id: '5412826dd74141ec3d000154', item: 913, location: [1189, 156]},
  {id: '54327989421aa90165001d82', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1214, 307]},
  {id: '54327993421aa90165001d8b', player_id: '527cdb0c9b57e053e5000061', item: 606, location: [1214, 307]},
  {id: '54327998421aa90165001d91', player_id: '5227db5baeac1d7d6c0000c0', item: 760, location: [1141, 123]},
  {id: '543279a2421aa90165001d96', player_id: '5227db5baeac1d7d6c0000c0', item: 782, location: [1150, 122]},
  {id: '543279c1421aa90165001da2', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1214, 307]},
  {id: '543279cb421aa90165001da7', player_id: '527cdb0c9b57e053e5000061', item: 605, location: [1214, 307]},
  {id: '543279d0421aa90165001da9', player_id: '527cdb0c9b57e053e5000061', item: 606, location: [1214, 307]},
  {id: '543279d0421aa90165001daa', player_id: '515a192e308be4b42000007b', item: 891, location: [1184, 98]},
  {id: '54327a18421aa90165001dbf', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1214, 307]},
  {id: '54327a1d421aa90165001dc1', player_id: '527cdb0c9b57e053e5000061', item: 606, location: [1211, 307]},
  {id: '54327a1d421aa90165001dc2', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1213, 307]},
  {id: '54327a27421aa90165001dc8', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1214, 307]},
  {id: '54327a2c421aa90165001dc9', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1212, 307]},
  {id: '54327a2c421aa90165001dca', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1213, 307]},
  {id: '54327a2c421aa90165001dcb', player_id: '527cdb0c9b57e053e5000061', item: 604, location: [1211, 307]},
  {id: '54327a2c421aa90165001dcc', player_id: '527cdb0c9b57e053e5000061', item: 606, location: [1210, 307]},
  {id: '54327df2421aa90165001e19', player_id: '5412826dd74141ec3d000154', item: 849, location: [1195, 156]},
  {id: '54327df7421aa90165001e1b', player_id: '5412826dd74141ec3d000154', item: 849, location: [1195, 156]},
  {id: '54327f76421aa90165001e20', player_id: '515a192e308be4b42000007b', item: 891, location: [1184, 98]},
  {id: '54328805421aa90165001ebc', player_id: '535552ffb02e24df290000a8', item: 591, location: [54, 377]},
  {id: '54328805421aa90165001ebd', player_id: '535552ffb02e24df290000a8', item: 591, location: [56, 377]},
  {id: '54328805421aa90165001ebe', player_id: '535552ffb02e24df290000a8', item: 591, location: [58, 377]},
  {id: '54328805421aa90165001ebf', player_id: '535552ffb02e24df290000a8', item: 591, location: [60, 377]},
  {id: '54328805421aa90165001ec0', player_id: '535552ffb02e24df290000a8', item: 591, location: [62, 377]},
  {id: '54328842421aa90165001ec1', player_id: '52f6bb1551d7c79de5000073', item: 854, location: [388, 565]},
  {id: '543288ac421aa90165001ec2', player_id: '535552ffb02e24df290000a8', item: 604, location: [72, 380]},
  {id: '543288ac421aa90165001ec3', player_id: '535552ffb02e24df290000a8', item: 604, location: [71, 380]},
  {id: '543288ac421aa90165001ec4', player_id: '535552ffb02e24df290000a8', item: 604, location: [70, 380]},
  {id: '543288ac421aa90165001ec5', player_id: '535552ffb02e24df290000a8', item: 604, location: [69, 380]},
  {id: '543288ac421aa90165001ec6', player_id: '535552ffb02e24df290000a8', item: 604, location: [68, 380]},
  {id: '543288ac421aa90165001ec7', player_id: '535552ffb02e24df290000a8', item: 604, location: [67, 380]},
  {id: '543288ac421aa90165001ec8', player_id: '535552ffb02e24df290000a8', item: 604, location: [66, 380]},
  {id: '543288ac421aa90165001ec9', player_id: '535552ffb02e24df290000a8', item: 604, location: [65, 380]},
  {id: '543288b1421aa90165001eca', player_id: '535552ffb02e24df290000a8', item: 606, location: [63, 380]},
  {id: '543288b1421aa90165001ecb', player_id: '535552ffb02e24df290000a8', item: 606, location: [62, 380]},
  {id: '543288b1421aa90165001ecc', player_id: '535552ffb02e24df290000a8', item: 606, location: [61, 380]},
  {id: '543288b1421aa90165001ecd', player_id: '535552ffb02e24df290000a8', item: 606, location: [60, 380]},
  {id: '543288b1421aa90165001ece', player_id: '535552ffb02e24df290000a8', item: 606, location: [59, 380]},
  {id: '543288b1421aa90165001ecf', player_id: '535552ffb02e24df290000a8', item: 584, location: [58, 381]},
  {id: '543288b1421aa90165001ed0', player_id: '535552ffb02e24df290000a8', item: 584, location: [59, 381]},
  {id: '543288b1421aa90165001ed1', player_id: '535552ffb02e24df290000a8', item: 584, location: [60, 381]},
  {id: '543288b1421aa90165001ed2', player_id: '535552ffb02e24df290000a8', item: 584, location: [58, 382]},
  {id: '543288b1421aa90165001ed3', player_id: '535552ffb02e24df290000a8', item: 584, location: [59, 382]},
  {id: '543288b6421aa90165001ed4', player_id: '535552ffb02e24df290000a8', item: 584, location: [60, 382]},
  {id: '543288b6421aa90165001ed5', player_id: '535552ffb02e24df290000a8', item: 585, location: [53, 381]},
  {id: '543288b6421aa90165001ed6', player_id: '535552ffb02e24df290000a8', item: 585, location: [52, 381]},
  {id: '543288b6421aa90165001ed7', player_id: '535552ffb02e24df290000a8', item: 585, location: [54, 381]},
  {id: '543288b6421aa90165001ed8', player_id: '535552ffb02e24df290000a8', item: 585, location: [54, 382]},
  {id: '543288b6421aa90165001ed9', player_id: '535552ffb02e24df290000a8', item: 585, location: [53, 382]},
  {id: '543288b6421aa90165001eda', player_id: '535552ffb02e24df290000a8', item: 585, location: [52, 382]},
  {id: '543288b6421aa90165001edb', player_id: '535552ffb02e24df290000a8', item: 585, location: [51, 382]},
  {id: '543288b6421aa90165001edc', player_id: '535552ffb02e24df290000a8', item: 585, location: [51, 381]},
  {id: '543288bb421aa90165001edd', player_id: '535552ffb02e24df290000a8', item: 305, location: [62, 382]},
  {id: '543288bb421aa90165001ede', player_id: '535552ffb02e24df290000a8', item: 604, location: [64, 380]},
  {id: '543288c0421aa90165001edf', player_id: '535552ffb02e24df290000a8', item: 307, location: [71, 385]},
  {id: '543288c0421aa90165001ee0', player_id: '535552ffb02e24df290000a8', item: 307, location: [72, 385]},
  {id: '543288c0421aa90165001ee1', player_id: '535552ffb02e24df290000a8', item: 307, location: [73, 385]},
  {id: '543288c0421aa90165001ee2', player_id: '535552ffb02e24df290000a8', item: 306, location: [64, 385]},
  {id: '543288c0421aa90165001ee3', player_id: '535552ffb02e24df290000a8', item: 306, location: [63, 385]},
  {id: '543288c0421aa90165001ee4', player_id: '535552ffb02e24df290000a8', item: 306, location: [62, 385]},
  {id: '543288ca421aa90165001ee5', player_id: '535552ffb02e24df290000a8', item: 754, location: [61, 376]},
  {id: '543288ca421aa90165001ee6', player_id: '535552ffb02e24df290000a8', item: 754, location: [61, 377]},
  {id: '543288cf421aa90165001ee7', player_id: '535552ffb02e24df290000a8', item: 754, location: [46, 386]},
  {id: '543288cf421aa90165001ee8', player_id: '535552ffb02e24df290000a8', item: 754, location: [46, 387]},
  {id: '543288cf421aa90165001ee9', player_id: '535552ffb02e24df290000a8', item: 754, location: [46, 388]},
  {id: '543288cf421aa90165001eea', player_id: '535552ffb02e24df290000a8', item: 754, location: [46, 389]},
  {id: '543288d4421aa90165001eeb', player_id: '535552ffb02e24df290000a8', item: 780, location: [48, 391]},
  {id: '543288d4421aa90165001eec', player_id: '535552ffb02e24df290000a8', item: 780, location: [48, 388]},
  {id: '543288d9421aa90165001eed', player_id: '535552ffb02e24df290000a8', item: 755, location: [50, 388]},
  {id: '543288d9421aa90165001eee', player_id: '535552ffb02e24df290000a8', item: 780, location: [50, 391]},
  {id: '543288d9421aa90165001eef', player_id: '535552ffb02e24df290000a8', item: 760, location: [50, 394]},
  {id: '543288d9421aa90165001ef0', player_id: '535552ffb02e24df290000a8', item: 583, location: [49, 394]},
  {id: '543288d9421aa90165001ef1', player_id: '535552ffb02e24df290000a8', item: 760, location: [48, 394]},
  {id: '543288de421aa90165001ef2', player_id: '535552ffb02e24df290000a8', item: 913, location: [46, 397]},
  {id: '543288de421aa90165001ef3', player_id: '535552ffb02e24df290000a8', item: 762, location: [49, 397]},
  {id: '543288de421aa90165001ef4', player_id: '535552ffb02e24df290000a8', item: 785, location: [48, 399]},
  {id: '543288e3421aa90165001ef5', player_id: '535552ffb02e24df290000a8', item: 913, location: [45, 399]},
  {id: '543288e3421aa90165001ef6', player_id: '535552ffb02e24df290000a8', item: 969, location: [43, 398]},
  {id: '543288ed421aa90165001ef7', player_id: '535552ffb02e24df290000a8', item: 919, location: [61, 402]},
  {id: '543288f7421aa90165001ef8', player_id: '535552ffb02e24df290000a8', item: 939, location: [82, 405]},
  {id: '54328906421aa90165001ef9', player_id: '535552ffb02e24df290000a8', item: 737, location: [103, 385]},
  {id: '54328906421aa90165001efa', player_id: '535552ffb02e24df290000a8', item: 737, location: [104, 385]},
  {id: '54328906421aa90165001efb', player_id: '535552ffb02e24df290000a8', item: 737, location: [105, 385]},
  {id: '54328906421aa90165001efc', player_id: '535552ffb02e24df290000a8', item: 737, location: [103, 386]},
  {id: '54328906421aa90165001efd', player_id: '535552ffb02e24df290000a8', item: 737, location: [104, 386]},
  {id: '54328906421aa90165001efe', player_id: '535552ffb02e24df290000a8', item: 737, location: [105, 386]},
  {id: '54328906421aa90165001eff', player_id: '535552ffb02e24df290000a8', item: 737, location: [106, 385]},
  {id: '54328906421aa90165001f00', player_id: '535552ffb02e24df290000a8', item: 737, location: [106, 386]},
  {id: '5432891a421aa90165001f01', player_id: '535552ffb02e24df290000a8', item: 780, location: [68, 391]},
  {id: '5432891a421aa90165001f02', player_id: '535552ffb02e24df290000a8', item: 780, location: [66, 391]},
  {id: '5432891a421aa90165001f03', player_id: '535552ffb02e24df290000a8', item: 780, location: [64, 391]},
  {id: '5432891f421aa90165001f04', player_id: '535552ffb02e24df290000a8', item: 780, location: [62, 391]},
  {id: '5432891f421aa90165001f05', player_id: '535552ffb02e24df290000a8', item: 780, location: [60, 391]},
  {id: '5432891f421aa90165001f06', player_id: '535552ffb02e24df290000a8', item: 780, location: [58, 391]},
  {id: '5432891f421aa90165001f07', player_id: '535552ffb02e24df290000a8', item: 780, location: [52, 391]},
  {id: '5432891f421aa90165001f08', player_id: '535552ffb02e24df290000a8', item: 780, location: [54, 391]},
  {id: '5432891f421aa90165001f09', player_id: '535552ffb02e24df290000a8', item: 780, location: [56, 391]},
  {id: '5432891f421aa90165001f0a', player_id: '535552ffb02e24df290000a8', item: 781, location: [52, 393]},
  {id: '5432891f421aa90165001f0b', player_id: '535552ffb02e24df290000a8', item: 782, location: [52, 395]},
  {id: '5432891f421aa90165001f0c', player_id: '535552ffb02e24df290000a8', item: 967, location: [54, 393]},
  {id: '5432891f421aa90165001f0d', player_id: '535552ffb02e24df290000a8', item: 967, location: [56, 393]},
  {id: '54328924421aa90165001f0e', player_id: '535552ffb02e24df290000a8', item: 967, location: [58, 393]},
  {id: '54328924421aa90165001f0f', player_id: '535552ffb02e24df290000a8', item: 764, location: [58, 394]},
  {id: '54328924421aa90165001f10', player_id: '535552ffb02e24df290000a8', item: 967, location: [66, 393]},
  {id: '54328924421aa90165001f11', player_id: '535552ffb02e24df290000a8', item: 967, location: [64, 393]},
  {id: '54328924421aa90165001f12', player_id: '535552ffb02e24df290000a8', item: 967, location: [62, 393]},
  {id: '54328924421aa90165001f13', player_id: '535552ffb02e24df290000a8', item: 967, location: [60, 393]},
  {id: '54328929421aa90165001f14', player_id: '535552ffb02e24df290000a8', item: 691, location: [66, 388]},
  {id: '54328929421aa90165001f15', player_id: '535552ffb02e24df290000a8', item: 691, location: [66, 389]},
  {id: '54328929421aa90165001f16', player_id: '535552ffb02e24df290000a8', item: 691, location: [67, 387]},
  {id: '54328929421aa90165001f17', player_id: '535552ffb02e24df290000a8', item: 691, location: [67, 388]},
  {id: '54328929421aa90165001f18', player_id: '535552ffb02e24df290000a8', item: 797, location: [58, 389]},
  {id: '5432892f421aa90165001f19', player_id: '535552ffb02e24df290000a8', item: 797, location: [56, 389]},
  {id: '5432892f421aa90165001f1a', player_id: '535552ffb02e24df290000a8', item: 797, location: [61, 389]},
  {id: '5432892f421aa90165001f1b', player_id: '535552ffb02e24df290000a8', item: 807, location: [52, 389]},
  {id: '54328948421aa90165001f1c', player_id: '535552ffb02e24df290000a8', item: 965, location: [86, 384]},
  {id: '5432b02b421aa96cf3000556', player_id: '4f668f2e438103000d000003', item: 849, location: [1192, 332]},
  {id: '5432b263421aa96ce800033f', player_id: '4f668f2e438103000d000003', item: 849, location: [1189, 333]}]
end
