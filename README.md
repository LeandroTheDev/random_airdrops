# Random Airdrops
A mod for Project Zomboid creating a fully random airdrops to the server, and also fully customizable, you can change the loot tables, hours to remove, chance to spawn every hour, spawn coordinates.

### Features
- Airdrops never spawn above each other
- Airdrops doenst despawn if player is close
- Message to player chat when the airdrop is spawned + area name
- Air plane sound when the air drop spawn
- If the servers close, old airdrops will be deleted automatically
- Fully customizable loot table (see the github wiki)
- Fully customizable spawn coordinates (see the github wiki)

### How it works?
- The server random a chance if the chances hits ok then the airdrop coordinates is stored in "cache"
- if the cache have airdrops then the server starting ticking every 30 ticks to check if there is a player to spawn the airdrop (vehicles cannot spawn without a chunk been loading) in that specific position, also when the airdrop is created is removed from the cache
- if the chunk in that specific position is loaded then the airdrop will be created
- when the timer goes below the 0 the airdrop will be removed from the world and from the cache if not created yet, unless the player is loading the chunk of the airdrop
- when the server starts all old airdrops will be despawned when the chunk loads

[Changing The Loot Table](https://github.com/LeandroTheDev/random_airdrops/wiki/Creating-Loot-Tables)

[Changing Airdrop Spawn Coordinates](https://github.com/LeandroTheDev/random_airdrops/wiki/Adding-New-Coordinates-to-Spawn)