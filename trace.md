ruby-prof -f prof/`date +%s`.txt -s total deepworld.rb
ruby-prof --mode=wall -f prof/`date +%s`.txt deepworld.rb 25
