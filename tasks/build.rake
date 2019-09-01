task :build do
  ['zone_kernel'].each do |src|
    build src
  end
end

def build(src)
  ext_path = File.expand_path('../../ext', __FILE__)

  puts "------------------------"
  puts "Build #{src}..."
  puts "------------------------\n"

  puts 'Deleting old build files...'
  ["#{src}.bundle", "#{src}.o"].each do |f|
    `rm -f #{ext_path}/#{f}` if File.exists?("#{ext_path}/#{f}")
  end

  puts "Compiling..."
  puts `cd ext && ruby #{src}_extconf.rb && make && make install`

  `rm ./ext/MAKEFILE`
  `rm ./ext/mkmf.log`
end
