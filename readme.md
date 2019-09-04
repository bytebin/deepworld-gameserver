## Deepworld Game Server

This is the game server, the core system used to run the Massively Multiplayer online crafting adventure game Deepworld. We would typically run 1-2 servers per core and expect roughly 1gb maximum memory usage per server.

The codebase is primarily written in Ruby and heavily leverages [EventMachine](https://github.com/eventmachine/eventmachine) an evented concurrency framework with a fair amount of the serious bit twiddling written directly in C.

The server heavily relies on the [Deepworld Master Config](https://github.com/bytebin/deepworld-config) for game logic, so be sure to dig into that as well.

We plan to provide a better treasure map over the coming days/weeks, but in the codebase you'll find many things including:

- An applicaton protocol, leveraging MessagePack [server/messages/base_message.rb](./server/messages/base_message.rb) and [server/commands/command_directory.rb](./server/commands/command_directory.rb)
- An behavior tree AI system [vendor/rubyhave](./vendor/rubyhave) gem and [models/npcs/behavior](./models/npcs/behavior)
- A [em-mongo](https://github.com/bcg/em-mongo) based mongodb query library proving a simple mongo API [lib/mongo_model](./lib/mongo_model)
- A steam power system to connecting steam vents to "power" machines [ext/lib/steam.c](./ext/lib/steam.c)
- A simple liquid dynamics system [ext/lib/liquid.c](./ext/lib/liquid.c)
- A "plant growth" system to progress plants based on exposure to light and water [ext/lib/light.c](./ext/lib/light.c) and [ext/lib/growth.c](./ext/lib/growth.c)
- A binary world data format stored in chunks / blocks including a migration system inspired by ActiveRecord [models/zone.rb](./models/zone.rb) and [ext/lib/zone.c](./ext/lib/zone.c)
- An _extremely comprehensive_ [RSpec](https://rspec.info/) test suite [spec folder](./spec)
- A simulator to connect and control sim players for testing [script/simulator](./script/simulator)
- Many many more things that we're forgetting but hopefully will enumerate in the coming days
