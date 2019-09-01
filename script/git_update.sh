git fetch
git stash
git rebase origin/master
git stash pop
bundle install --without development test --deployment
rake build

if [ $# -gt 1 ] && [ "${!#}" == '-r' ]
  then restart deepworld
fi