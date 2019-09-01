require 'json'
require 'msgpack'

data = File.read('spec/data/bootstrap.zone.json')
json = JSON.parse(data)
pack = MessagePack.pack(json)

File.open('spec/data/bootstrap.zone.tmp', 'w') do |f| 
  f.write pack
end

p MessagePack.unpack(File.read('spec/data/bootstrap.zone.tmp').force_encoding('ASCII-8BIT'))[5]['187464']