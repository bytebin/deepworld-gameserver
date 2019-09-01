guard 'rspec', :cli => "--color --format nested", :version => 2, :all_after_pass => false, :all_on_start => false, :keep_failed => false do
  watch(/^spec\/(.*)_spec.rb/)

  watch(/^config\/initializers\/(.*)\.rb/)              { "spec" }
  watch(/^config\/(.*)\.yml/)                           { "spec" }
  watch(/^lib\/(.*)\.rb/)                               { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(/^spec\/spec_helper.rb/)                        { "spec" }
  watch(/^server\/(.*)\.rb/)                            { |m| "spec/server/#{m[1]}_spec.rb" }
  watch(/^server\/commands\/(.*)\.rb/)                  { |m| "spec/commands/#{m[1]}_spec.rb" }
  watch(/^server\/messages\/(.*)\.rb/)                  { |m| "spec/messages/#{m[1]}_spec.rb" }
  watch(/^models\/(.*)\.rb/)                            { |m| "spec/models/#{m[1]}_spec.rb" }
end