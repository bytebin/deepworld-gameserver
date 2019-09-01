# Make sure you install valgrind first: brew install valgrind
# http://blog.flavorjon.es/2009/06/easily-valgrind-gdb-your-ruby-c.html
namespace :test do
  # partial-loads-ok and undef-value-errors necessary to ignore
  # spurious (and eminently ignorable) warnings from the ruby
  # interpreter
  VALGRIND_BASIC_OPTS = "--num-callers=50 --error-limit=no \
                         --partial-loads-ok=yes --undef-value-errors=no --dsymutil=yes --leak-check=full"

  desc "run server under valgrind with basic ruby options"
  task :valgrind => :build do
    cmdline = "valgrind #{VALGRIND_BASIC_OPTS} ruby deepworld.rb"
    puts cmdline
    system cmdline
  end
end
