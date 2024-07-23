# Random Airdrops
A mod for Project Zomboid creating a fully random airdrops to the server, and also fully customizable, you can change the loot tables, hours to remove, chance to spawn every hour, spawn coordinates.

The mod is compatible with dedicated servers and singleplayer

### Features
- Airdrops never spawn above each other
- Airdrops doenst despawn if player is close
- Message to player chat when the airdrop is spawned + area name (Only in servers, because single player doenst have chat)
- Air plane sound when the air drop spawn
- If the servers close, old airdrops will be deleted automatically (Configurable)
- Fully customizable loot table (see the github wiki)
- Fully customizable spawn coordinates (see the github wiki)
- Where is the [Smoke Flare](https://github.com/LeandroTheDev/ra_smoke_flares/tree/main)? smoke flare is removed from the Random Airdrops, and now is a addon mod with the name [RA Smoke Flare](https://github.com/LeandroTheDev/ra_smoke_flares/tree/main)

### How it works?
- The server random a chance if the chances hits ok then the airdrop coordinates is stored in "cache"
- if the cache have airdrops then the server starting ticking every 30 ticks to check if there is a player to spawn the airdrop (vehicles cannot spawn without a chunk been loading) in that specific position, also when the airdrop is created is removed from the cache
- if the chunk in that specific position is loaded then the airdrop will be created
- when the timer goes below the 0 the airdrop will be removed from the world and from the cache if not created yet, unless the player is loading the chunk of the airdrop
- when the server starts all old airdrops will be despawned when the chunk loads

### Important
- Disable Despawn and Disable Old Spawn, are features not very tested, use with careful

### Questions
- Can i use in my server? yes
- Can i reupload this to workshop? yes
- Can i modify this mod? yes
- Can i share this mod? yes
- Can i steal this mod? only if the name is changed
- Can i charge for this mod? only if the name is changed

### For Modders
- You can free modify and make your own modification of this mod, also this mod have a [wiki framework](https://github.com/LeandroTheDev/random_airdrops/wiki/Framework) to you undestand and make a script or modification of this mod

[Changing The Loot Table](https://github.com/LeandroTheDev/random_airdrops/wiki/Creating-Loot-Tables)

[Changing Airdrop Spawn Coordinates](https://github.com/LeandroTheDev/random_airdrops/wiki/Adding-New-Coordinates-to-Spawn)
