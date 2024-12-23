---@diagnostic disable: undefined-global, deprecated
-- By bobodev the furious has a name 😊😊

-- Performance variables
-- ticks to wait to spawn or despawn the airdrop
local ticksPerCheck = 0;                                   -- Used for spawn
local ticksPerCheckDespawn = 0;                            -- Used for despawn
local ticksMax = SandboxVars.AirdropMain.AirdropTickCheck; -- Used for storing the tickrate passed when using the ticksPerCheck/ticksPerCheckDespawn
local giveUpDespawn = 0;                                   -- Used when we cannot despawn the airdrop, because the airdrop is missing

-- #region Lua Utils
-- Clone the entire table
local function deepcopy(orig)
    local copy

    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end

    return copy
end
-- #endregion

-- Stores the Lua config with the spawner positions
-- [
--  {
--      x = 10,
--      y = 10,
--      z = 1,
--      name = "Example"
--  }
-- ]
local airdropPositions = {};
-- Stores the Lua config with the items to spawn in airdrop
-- {
--  {
--      type = "combo",
--      chance = 100,
--      child = {
--          type = "item",
--          chance = 100,
--          quantity = 5,
--          child = "Base.Axe"
--      }
--  }
-- }
local airdropLootTable = {};
-- Stores globally all airdrops that has already spawned
-- this variable is used to remove the airdrop after some configurated time
-- [
--  {
--      airdrop = BaseVehicle / The airdrop instance / should be null if not created yet (in the world)
--      ticksToDespawn = int / used to check if the airdrop needs to be despawned, DespawnAirdrops use this
--      index = int / the index from the airdropPositions
--  }
-- ]
SpawnedAirdrops = {};
-- Stores globally the airdrops that is not created in the world yet
-- used for the function CheckForCreateAirdrop, that always tries to
-- spawn the airdrop, (airdrops cannot be spawned if the chunk not loaded)
-- [
--  1, / airdropPositions - index
--  2, / airdropPositions - index
-- ]
AirdropsToSpawn = {};
-- Stores the airdrop datas
-- OldAirdrops = List<spawnIndex> / stores all airdrops indexes that needs to be removed after the server closes: [1,2,3]
-- OldAirdropsData = List<spawnArea, ticksToDespawn> / old airdrop datas, used when the DisableOldDespawn is true: [{ticksToDespawn = 1, index = 1}]
-- RemovingOldAirdrops = List<spawnIndex> / all airdrops to be removed, allocated when starting the server: [1,2,3]
-- SpecificAirdropsSpawned = List<spawnArea, ticksToDespawn> / all airdrops spawneds by other mods: [{ticksToDespawn = 1, index = 1}]
AirdropsData = {};

-- Read airdrop positions from Lua file
local function readAirdropsPositions()
    print("[Air Drop] Loading air drops positions...")
    local fileReader = getFileReader("AirdropPositions.ini", true)
    local lines = {}
    local line = fileReader:readLine()
    while line do
        table.insert(lines, line)
        line = fileReader:readLine()
    end
    fileReader:close()
    airdropPositions = loadstring(table.concat(lines, "\n"))() or {}
    print("[Air Drop] Positions loaded");
end

-- Read airdrop loot table from Lua file
local function readAirdropsLootTable()
    print("[Air Drop] Loading air drops loot table...")
    local fileReader = getFileReader("AirdropLootTable.ini", true)
    local lines = {}
    local line = fileReader:readLine()
    while line do
        table.insert(lines, line)
        line = fileReader:readLine()
    end
    fileReader:close()
    airdropLootTable = loadstring(table.concat(lines, "\n"))() or {}
    print("[Air Drop] Loot table loaded");
end

-- Check if exist player reading the airdrop chunk
local function checkPlayersAround(airdrop)
    -- Getting airdrop coords
    local airdropX = airdrop:getX();
    local airdropY = airdrop:getY();
    local airdropZ = airdrop:getZ();

    -- Pikcup the airdrop square
    local square = getCell():getGridSquare(airdropX, airdropY, airdropZ);

    -- If the square exist, theres is a player loading the chunk
    if square then
        print("[Air Drop] Cannot despawn airdrop, a player is rendering close");
        return true;
    else
        return false
    end
end

-- Add items to the airdrop
local function spawnAirdropItems(airdrop)
    -- if you understand how this function works, i give you 10 bucks (joking)
    -- Colecting the airdrop container
    local airdropContainer = airdrop:getPartById("TruckBed"):getItemContainer();

    -- Used for the ID attribute, all ids stored here will be ignored during the loot spawn
    local idSpawneds = {};

    local alocatedSelectedType
    -- swipe the list and call the functions
    -- based on the type.
    -- the function needs to be an parameter because
    -- its is referenced after the listSpawn
    local function listSpawn(list, selectType)
        alocatedSelectedType = selectType;
        -- Swipe all elements from the list
        for i = 1, #list do
            selectType(list[i]);
        end
    end

    -- Type: item
    local function spawnItem(child)
        airdropContainer:AddItem(child);
    end

    -- Type: combo
    local function spawnCombo(child)
        -- Varremos todos os elementos do loot table
        listSpawn(child, alocatedSelectedType);
    end

    -- Type: oneof
    local function spawnOneof(child)
        local selectedIndex = ZombRand(#child) + 1;
        -- listSpawn only accepts lists so we needs to get the specific item
        alocatedSelectedType(child[selectedIndex]);
    end

    local function selectType(element)
        local jump = false;
        -- Checking if the variable ID exist
        if element.id then
            -- Verifying if the id has already added
            if idSpawneds[element.id] then jump = true end
        end
        -- Checking if the chancce is null
        if not element.chance then element.chance = 100 end
        -- Verifying if doesnt need to jump
        if not jump then
            -- Verifying the type
            if element.type == "combo" then
                -- Veryfing if the element has any ID
                if element.id then
                    -- If exist then add it to the idSpawneds list
                    idSpawneds[element.id] = true;
                end
                -- Verifying if quantity is not null
                if element.quantity then
                    -- Add based on the quantity
                    for _ = 1, element.quantity do
                        -- Getting the chance to spawn the child
                        if ZombRand(100) + 1 <= element.chance then
                            -- Adding the item
                            spawnCombo(element.child);
                        end
                    end
                else
                    -- Getting the chance to spawn the child
                    if ZombRand(100) + 1 <= element.chance then
                        -- Adding the item
                        spawnCombo(element.child);
                    end
                end
            elseif element.type == "item" then
                -- Veryfing if the element has any ID
                if element.id then
                    -- If exist then add it to the idSpawneds list
                    idSpawneds[element.id] = true;
                end
                -- Verifying if quantity is not null
                if element.quantity then
                    -- Add based on the quantity
                    for _ = 1, element.quantity do
                        -- Getting the chance to spawn the child
                        if ZombRand(100) + 1 <= element.chance then
                            -- Adding the item
                            spawnItem(element.child);
                        end
                    end
                else
                    -- Getting the chance to spawn the child
                    if ZombRand(100) + 1 <= element.chance then
                        -- Adding the item
                        spawnItem(element.child);
                    end
                end
            elseif element.type == "oneof" then
                -- Verifying if the element has any ID
                if element.id then
                    -- If have add it to idSpawneds list
                    idSpawneds[element.id] = true;
                end
                -- Verifying if quantity is not null
                if element.quantity then
                    -- Adding based on the quantity
                    for _ = 1, element.quantity do
                        -- Getting the chance to spawn the child
                        if ZombRand(100) + 1 <= element.chance then
                            -- Adding the item
                            spawnOneof(element.child);
                        end
                    end
                else
                    -- Getting the chance to spawn the child
                    if ZombRand(100) + 1 <= element.chance then
                        -- Adding the item
                        spawnOneof(element.child);
                    end
                end
            end
        end
    end

    -- Start the loot spawnm
    listSpawn(airdropLootTable, selectType);
end

-- Remove the element of AirdropsToSpawen by the Spawn Index
local function removeElementFromAirdropsToSpawnBySpawnIndex(spawnIndex)
    -- Swipe in AirdropsToSpawn
    for i = 1, #AirdropsToSpawn do
        -- Verify if the spawnIndex is the same as AirdropsToSpawn
        if spawnIndex == AirdropsToSpawn[i] then
            -- Remove from table
            table.remove(AirdropsToSpawn, i);
            break;
        end
    end
end

-- Remove the elemnt of SpawnedAirdrops by the Spawn Index
local function removeElementFromSpawnedAirdropsBySpawnIndex(spawnIndex)
    -- Swipe in SpawnedAirdrops
    for i = 1, #SpawnedAirdrops do
        -- Verify if the spawnIndex is the same as SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Remove from table
            table.remove(SpawnedAirdrops, i);
            break;
        end
    end
end

-- Remove the element from the AirdropsData by the Index
local function removeElementFromOldAirdropsDataBySpawnIndex(spawnIndex)
    -- Swipe in AirdropsData
    for i = 1, #AirdropsData.OldAirdropsData do
        -- Verify if the spawnIndex is the same as AirdropsData
        if spawnIndex == AirdropsData.OldAirdropsData[i].index then
            -- Remove from table
            table.remove(AirdropsData.OldAirdropsData, i);
            break;
        end
    end
end

-- Reduce the ticksToDespawn based on spawnIndex
local function reduceTicksToDespawnFromSpawnedAirdropsBySpawnIndex(spawnIndex)
    -- Swipe in SpawnedAirdrops
    for i = 1, #SpawnedAirdrops do
        -- Verify if the spawnIndex is the same as SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Reduce from the table
            SpawnedAirdrops[i].ticksToDespawn = SpawnedAirdrops[i].ticksToDespawn - 1;
            break;
        end
    end
end

-- Reduce the ticksToDespawn based on spawnIndex
local function reduceTicksToDespawnFromOldAirdropsDataBySpawnIndex(spawnIndex)
    -- Swipe in OldAirdropsData
    for i = 1, #AirdropsData.OldAirdropsData do
        -- Verify if the spawnIndex is the same as OldAirdropsData
        if spawnIndex == AirdropsData.OldAirdropsData[i].index then
            --- Reduce from the table
            AirdropsData.OldAirdropsData[i].ticksToDespawn = AirdropsData.OldAirdropsData[i].ticksToDespawn - 1;
            break;
        end
    end
end

-- Add the airdrop in SpawnedAirdrops based on spawnIndex
local function addAirdropToSpawnedAirdropsBySpawnIndex(spawnIndex, airdrop)
    -- Swipe in SpawnedAirdrops
    for i = 1, #SpawnedAirdrops do
        -- Verifying if spawnIndex is the same from SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Add the airdrop to the SpawnedAirdrops index
            SpawnedAirdrops[i].airdrop = airdrop;
            -- Adding the spawnIndex to OldAirdrops to be removed
            table.insert(AirdropsData.OldAirdrops, spawnIndex);
            break;
        end
    end
end

-- Remove the airdrop from the OldAirdrops based in spawnIndex
local function removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex)
    -- Swipe all OldAirdrops
    for i = 1, #AirdropsData.OldAirdrops do
        -- Verifying if the spawnIndex is the same as OldAirdrops
        if spawnIndex == AirdropsData.OldAirdrops[i] then
            -- Remove it from the table
            table.remove(AirdropsData.OldAirdrops, i)
            break;
        end
    end
end

-- Remove o da lista de RemovingOldAirdrop pelo Id do airdrop
local function removeAirdropFromRemovingAirdropsBySpawnIndex(spawnIndex)
    -- Varredura nos OldAirdrops
    for i = 1, #AirdropsData.RemovingOldAirdrops do
        -- Verifica se o id é o mesmo do OldAirdrops
        if spawnIndex == AirdropsData.RemovingOldAirdrops[i] then
            table.remove(AirdropsData.RemovingOldAirdrops, i)
            break;
        end
    end
end

-- Verify if the airdrop spawnIndex any OldAirdrop in that position
local function checkOldAirdropsExistenceBySpawnIndex(spawnIndex)
    -- Swipe OldAirdrops
    for i = 1, #AirdropsData.OldAirdrops do
        -- Verifying if the ID is the same
        if spawnIndex == AirdropsData.OldAirdrops[i] then
            -- Exist
            return true;
        end
    end
    -- Not exist
    return false;
end

-- Verify if the airdrop spawnIndex any AirdropsToSpawn in that position
local function checkAirdropsToSpawnExistenceBySpawnIndex(spawnIndex)
    -- Swipe OldAirdrops
    for i = 1, #AirdropsToSpawn do
        -- Verifying if the ID is the same
        if spawnIndex == AirdropsToSpawn[i] then
            -- Exist
            return true;
        end
    end
    -- Not exist
    return false;
end

-- Verify if the airdrop spawnIndex exist in RemovingOldAirdrops
local function checkRemovingOldAirdropsExistenceBySpawnIndex(spawnIndex)
    -- Swipe OldAirdrops
    for i = 1, #AirdropsData.RemovingOldAirdrops do
        -- Verifying if the ID is the same
        if spawnIndex == AirdropsData.RemovingOldAirdrops[i] then
            -- Exist
            return true;
        end
    end
    -- Not exist
    return false;
end

-- Verify if exist any spawnIndex in SpawnedAirdrops
local function checkSpawnAirdropsExistenceBySpawnIndex(spawnIndex)
    -- Swipe in SpawnedAirdrops
    for i = 1, #SpawnedAirdrops do
        -- Verifying if the spawnIndex is the same
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Exist
            return true;
        end
    end
    -- Not exist
    return false;
end

-- Check if it will spawn any airdrop
function CheckAirdrop()
    -- Also try to despawn airdrops
    if not SandboxVars.AirdropMain.AirdropDisableDespawn then
        DespawnAirdrops();
    end
    -- Check if should spawn any airdrop
    if ZombRand(100) + 1 <= SandboxVars.AirdropMain.AirdropFrequency then
        -- Spawning the airdrop
        local airdropLocationName = SpawnAirdrop();
        -- Veryfing if the airdrop sucessfully spawned
        if not airdropLocationName then return end;
        -- Get the online player list
        local players = getOnlinePlayers();
        -- Singleplayer compatibility
        if not players then
            -- Sound to send to the player
            local alarmSound = "airdrop" .. tostring(ZombRand(1));
            -- Alocate the sound in memory
            local sound = getSoundManager():PlaySound(alarmSound, false, 0);
            -- Give it to the player
            getSoundManager():PlayAsMusic(alarmSound, sound, false, 0);
            sound:setVolume(0.1);
        else -- Server side
            -- Alert the players that the airdrop has spawned
            for i = 0, players:size() - 1 do
                -- Get the player by index
                local player = players:get(i)
                -- Alert the player
                sendServerCommand(player, "ServerAirdrop", "alert", { name = airdropLocationName });
            end
        end
    else
        print("[Air Drop] Global airdrop check no");
    end
end

-- Spawn any random airdrop on the world based on AirdropPositions
function SpawnAirdrop()
    local spawnIndex = 0;

    -- Select any area randomly
    local tries = 20;
    while tries > 0 do
        -- Check if airdropPositions is empty
        if #airdropPositions == 0 then
            tries = 0; break;
        end
        -- Getting the spawn index
        spawnIndex = ZombRand(#airdropPositions) + 1
        local alreadySpawned = false;
        -- Varre todos os airdrops spawnados para ver se o index é diferente
        for i = 1, #SpawnedAirdrops do
            -- Verificamos se o index já foi usado
            if SpawnedAirdrops[i].index == spawnIndex then
                -- Refaça
                alreadySpawned = true;
                break;
            end
        end
        -- Se a variavel disable old despawn estiver ativa então
        -- precisamos verificar também se não existe spawnado já no OldAirdrops
        if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
            -- Varre todos os airdrops spawnados para ver se o index é diferente
            for i = 1, #AirdropsData.OldAirdrops do
                -- Verificamos se o index já foi usado
                if AirdropsData.OldAirdrops[i] == spawnIndex then
                    -- Refaça
                    alreadySpawned = true;
                    break;
                end
            end
        end
        -- Se ja spawno então
        if alreadySpawned then
            -- Reduzimos a menos 1 as tentativas
            tries = tries - 1;
        end
        -- Verifica se não foi spawnado ainda
        if not alreadySpawned then break end
        print("[Air Drop] Cannot spawn airdrop, the index " .. spawnIndex .. " has already in use");
    end

    -- Caso não encontre um index que não foi spawnado
    if tries <= 0 then
        print("[Air Drop] Warning cannot find a spawn area that has not been spawned, air drop not spawned");
        return nil;
    end

    -- Recebemos a area de spawn
    local spawnArea = airdropPositions[spawnIndex];

    -- Adicionamos a lista de airdrops spawnados
    table.insert(SpawnedAirdrops,
        { airdrop = nil, ticksToDespawn = SandboxVars.AirdropMain.AirdropRemovalTimer, index = spawnIndex });
    -- Adicionamos na lista de airdrops ainda para spawnar
    table.insert(AirdropsToSpawn, spawnIndex);

    -- Precisamos verificar se DisableOldDespawn esta ativo
    -- para podermos adicionar os dados a OldAirdropsData
    if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
        -- Adicionamos a lista de OldAirdropsData
        table.insert(AirdropsData.OldAirdropsData,
            { airdrop = false, ticksToDespawn = SandboxVars.AirdropMain.AirdropRemovalTimer, index = spawnIndex });
    end

    -- Precisamos fazer isso pois pode ser que tenha mais de um airdrop por dia
    -- e também não queremos que o evento seja seja duplicado
    -- Removemos ticks anteriores
    Events.OnTick.Remove(CheckForCreateAirdrop);
    -- Readicionamos
    Events.OnTick.Add(CheckForCreateAirdrop);

    if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
        print("[Air Drop] Spawned in X:" ..
            spawnArea.x .. " Y: " .. spawnArea.y);
    end

    -- Retornamos o nome da area de spawn
    return spawnArea.name;
end

-- Reduz a setença para despawnar, chamado a cada hora ingame
-- se existir setenças Despawna os airdrops, caso for um Especial inicia
-- o evento OnTick para ForceDespawnAirdrops
function DespawnAirdrops()
    -- Precisamos salvar localmente a variavel para não ter atualizações indevidas
    -- durante o check, já que a atualização é feita durane o for
    local localSpawnedAirdrops = deepcopy(SpawnedAirdrops);
    -- Varremos todos os airdrops spawnados
    for i = 1, #localSpawnedAirdrops do
        -- Caso o airdrop não esteja setenciado apenas prossiga para o proximo
        if localSpawnedAirdrops[i].ticksToDespawn <= 0 then
            -- Recebemos o airdrop pelo indice
            local airdrop = localSpawnedAirdrops[i].airdrop;

            -- Checamos se airdrop é nulo e se esta setenciado
            -- Se estiver nulo significa que ele ainda não foi spawnado oficialmente
            if not airdrop then
                -- Getting the spawnIndex from SpawnedAirdrops
                local spawnIndex = localSpawnedAirdrops[i].index;
                -- Pegamos as posições diretamente do airdropPositions
                -- porque o aidrop não foi spawnado ainda
                print("[Air Drop] Uncreated Air drop has been removed in X:" ..
                    airdropPositions[spawnIndex].x .. " Y:" .. airdropPositions[spawnIndex].y);
                -- Removemos da nossa lista de AirdropsToSpawn
                removeElementFromAirdropsToSpawnBySpawnIndex(spawnIndex);
                -- Removemos da nossa lista de SpawnedAirdrops
                removeElementFromSpawnedAirdropsBySpawnIndex(spawnIndex);
                -- Verificamos se DisableOldDespawne esta ativo
                if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
                    -- Removemos da tabela de OldAirdropsData
                    removeElementFromOldAirdropsDataBySpawnIndex(spawnIndex)
                end
                -- Prosseguimos para o proximo indice
            else -- Caso o airdrop foi criado então temos alguma validações
                -- Checamos se existe algum jogador por perto
                local havePlayerAround = checkPlayersAround(airdrop);

                -- Se não há jogadores por perto
                if not havePlayerAround then
                    -- Removemos permanentemente do mundo
                    airdrop:permanentlyRemove();
                    print("[Air Drop] Air drop has been removed in X:" .. airdrop:getX() .. " Y:" .. airdrop:getY());

                    -- Getting the spawnIndex from SpawnedAirdrops
                    local spawnIndex = localSpawnedAirdrops[i].index;
                    -- Removemos da nossa lista de SpawnedAirdrops
                    removeElementFromSpawnedAirdropsBySpawnIndex(spawnIndex);
                    -- Removemos da nossa lista de OldAirdrops
                    removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex);
                    -- Verificamos se DisableOldDespawne esta ativo
                    if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
                        -- Removemos da tabela de OldAirdropsData
                        removeElementFromOldAirdropsDataBySpawnIndex(spawnIndex)
                    end
                end
            end
        else
            -- Reduzimos em 1 o tick para despawnar do airdrop
            reduceTicksToDespawnFromSpawnedAirdropsBySpawnIndex(localSpawnedAirdrops[i].index);
        end
    end

    -- Varremos todos os airdrops especiais
    for i = 1, #AirdropsData.SpecificAirdropsSpawned do
        -- Verificamos a setença
        if AirdropsData.SpecificAirdropsSpawned[i].ticksToDespawn <= 0 then
            -- Remove from specific list
            table.remove(AirdropsData.SpecificAirdropsSpawned, i);
            -- Add it to the old list
            table.insert(AirdropsData.OldSpecificAirdropsSpawned, AirdropsData.SpecificAirdropsSpawned[i]);
            -- Removemos e adicionamos para não ter problemas de memoria e performance
            Events.OnTick.Remove(ForceDespawnAirdrops);
            Events.OnTick.Add(ForceDespawnAirdrops);
        else
            -- Reduzimos a setença
            AirdropsData.SpecificAirdropsSpawned[i].ticksToDespawn = AirdropsData.SpecificAirdropsSpawned[i]
                .ticksToDespawn - 1;
        end
    end

    -- Se o DisableOldDespawn estiver ativo, precisamos verificar o OldAirdropsData
    if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
        -- Varremos todos os dados
        for i = 1, #AirdropsData.OldAirdropsData do
            local data = AirdropsData.OldAirdropsData[i];
            -- Verificamos se esta setenciado
            if data.ticksToDespawn <= 0 then
                -- Se a existencia de OldAirdrops não existe em SpawnedAirdrops
                if not checkSpawnAirdropsExistenceBySpawnIndex(data.index) then
                    -- Adicionamos ele ao RemovingOldAirdrops para ForceDespawnAirdrops
                    table.insert(AirdropsData.RemovingOldAirdrops, data.index);
                    -- Removemos e adicionamos para não ter problemas de memoria e performance
                    Events.OnTick.Remove(ForceDespawnAirdrops);
                    Events.OnTick.Add(ForceDespawnAirdrops);
                end
            else
                reduceTicksToDespawnFromOldAirdropsDataBySpawnIndex(data.index);
            end
        end
    end
end

-- Força e remove todos os airdrops na lista de RemovingOldAirdrops
-- Essa função é pesada pois faz uma varredura legal no mapa, não use com frequencia!
function ForceDespawnAirdrops()
    -- Checa a espera de ticks
    if ticksPerCheckDespawn < ticksMax then
        ticksPerCheckDespawn = ticksPerCheckDespawn + 1;
        return
    end
    ticksPerCheckDespawn = 0;
    -- Verificamos se RemovingOldAirdrops esta vazio e SpecificAirdropsSpawned esta vazio
    if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
        if #AirdropsData.RemovingOldAirdrops == 0 and #AirdropsData.SpecificAirdropsSpawned == 0 then
            --Remove o evento
            Events.OnTick.Remove(ForceDespawnAirdrops);
            print("[Air Drop] Finished cleaning the old air drops")
        end
    else -- Verificamos se RemovingOldAirdrops esta vazio e OldSpecificAirdropsSpawned esta vazio
        if #AirdropsData.RemovingOldAirdrops == 0 and #AirdropsData.OldSpecificAirdropsSpawned == 0 then
            --Remove o evento
            Events.OnTick.Remove(ForceDespawnAirdrops);
            print("[Air Drop] Finished cleaning the old air drops")
        end
    end

    -- Varredura nos airdrops e despawnamos
    local localOldAirdrops = deepcopy(AirdropsData.RemovingOldAirdrops)
    for i = 1, #localOldAirdrops do
        -- Coletamos o spawn index
        local spawnIndex = localOldAirdrops[i];
        -- Recebemos a area de spawn
        local spawnArea = airdropPositions[spawnIndex];
        -- Coletamos o square
        local square = getCell():getGridSquare(spawnArea.x, spawnArea.y, spawnArea.z);
        -- Verificamos se o chunk esta sendo carregado
        if square then
            -- Coletamos o airdrop
            local airdrop = square:getVehicleContainer();
            -- Verificamos se veiculo não está nulo
            if airdrop then
                -- Verificamos se o veiculo é o airdrop
                if airdrop:getScriptName() == "Base.airdrop" then
                    -- Removemos definitivamente
                    airdrop:permanentlyRemove();
                    removeAirdropFromRemovingAirdropsBySpawnIndex(spawnIndex)
                    removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex);
                    if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
                        print("[Air Drop] Force Despawn air drop has been removed in X:" ..
                            airdrop:getX() .. " Y:" .. airdrop:getY());
                    end
                else
                    print("[Air Drop] WARNING exist a vehicle in airdrop spawn coordinate giving up...")
                    removeAirdropFromRemovingAirdropsBySpawnIndex(spawnIndex)
                    removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex);
                end
            else
                -- Tentamos despawnar ate 6 vezes
                giveUpDespawn = giveUpDespawn + 1
                if giveUpDespawn >= 5 then
                    removeAirdropFromRemovingAirdropsBySpawnIndex(spawnIndex)
                    removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex);
                    giveUpDespawn = 0;
                    print("[Air Drop] WARNING give up despawning the airdrop...")
                else
                    print("[Air Drop] WARNING chunk loaded but airdrop not found")
                end
            end
        else
            -- Debug
            if SandboxVars.AirdropMain.AirdropConsoleDebug then
                print("[Air Drop] Force despawn: chunk not loaded in index: " .. spawnIndex);
            end;
        end
    end

    -- Verificamos se esta ativo a configuracao DisaleOldSpawn
    if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
        local empty = true;
        local localSpecificAirdropsSpawned = deepcopy(AirdropsData.SpecificAirdropsSpawned)
        for i = 1, #localSpecificAirdropsSpawned do
            -- Precisamos checar se ticksToDespawn é menor ou igual a 0
            -- ate pq ele nao pode despawnar se o ticks ainda não é 0
            if localSpecificAirdropsSpawned[i].ticksToDespawn <= 0 then
                empty = false;
                -- Recebemos a spawn area
                local spawnArea = localSpecificAirdropsSpawned[i].spawnArea
                -- Coletamos o square
                local square = getCell():getGridSquare(spawnArea.x, spawnArea.y, spawnArea.z);
                if square then
                    -- Coletamos o airdrop
                    local airdrop = square:getVehicleContainer();
                    -- Verificamos se veiculo não está nulo
                    if airdrop then
                        -- Verificamos se o veiculo é o airdrop
                        if airdrop:getScriptName() == "Base.airdrop" then
                            -- Removemos definitivamente
                            airdrop:permanentlyRemove();
                            -- Removemos do indice
                            table.remove(AirdropsData.SpecificAirdropsSpawned, i);
                            if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
                                print("[Air Drop] SPECIFIC Despawn air drop has been removed in X:" ..
                                    airdrop:getX() .. " Y:" .. airdrop:getY());
                            end
                        else
                            print("[Air Drop] WARNING exist a vehicle in SPECIFIC airdrop spawn coordinate giving up...")
                            -- Removemos do indice
                            table.remove(AirdropsData.SpecificAirdropsSpawned, i);
                        end
                    else
                        print("[Air Drop] WARNING chunk loaded but SPECIFIC airdrop not found, giving up")
                        -- Removemos do indice
                        table.remove(AirdropsData.SpecificAirdropsSpawned, i);
                    end
                end
            end
        end
        -- Se SpecificAirdropsSpawned estiver vazio e RemovingOldAirdrops também então vamos cancelar isso
        if empty and #AirdropsData.RemovingOldAirdrops == 0 then
            --Remove o evento
            Events.OnTick.Remove(ForceDespawnAirdrops);
            print("[Air Drop] Finished cleaning the old air drops")
        end
    else
        -- Airdrops spawnados pela função SpawnSpecificAirdrop, são diferentes
        -- dos airdrops convensionais pois eles spawnam em locais diferentes dos indexs
        -- usamos o old para nao excluir os novos obviamente
        local localSpecificAirdropsSpawned = deepcopy(AirdropsData.OldSpecificAirdropsSpawned)
        for i = 1, #localSpecificAirdropsSpawned do
            -- Recebemos a spawn area
            local spawnArea = localSpecificAirdropsSpawned[i].spawnArea

            -- Retorna verdadeiro se removeu com sucesso um airdrop, falso caso nao tenha removido
            local function tryRemoveAirdrop(square)
                if square then
                    -- Coletamos o airdrop
                    local airdrop = square:getVehicleContainer();
                    -- Verificamos se veiculo não está nulo
                    if airdrop then
                        -- Verificamos se o veiculo é o airdrop
                        if airdrop:getScriptName() == "Base.airdrop" then
                            -- Removemos definitivamente
                            airdrop:permanentlyRemove();
                            -- Removes do indice old
                            if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
                                print("[Air Drop] Specific airdrop has been removed in X:" ..
                                    airdrop:getX() .. " Y:" .. airdrop:getY());
                            end
                            return "removed";
                        else
                            --print("[Air Drop] WARNING exist a vehicle in SPECIFIC airdrop spawn coordinate giving up...")
                            return "vehicleExist";
                        end
                    else
                        --print("[Air Drop] WARNING chunk loaded but SPECIFIC airdrop not found, giving up");
                        return "airdropMissing";
                    end
                end
                return "notLoaded";
            end

            -- Tentamos encontrar o airdrop numa area de 5x5
            local removeResult = "notLoaded";
            for dx = -5, 5 do
                for dy = -5, 5 do
                    local square = getCell():getGridSquare(spawnArea.x + dx, spawnArea.y + dy, spawnArea.z);
                    removeResult = tryRemoveAirdrop(square);
                    if removeResult == "removed" then break end;
                end
                if removeResult == "removed" then break end;
            end

            -- Removing from table
            if removeResult == "removed" then
                table.remove(AirdropsData.OldSpecificAirdropsSpawned, i);
            else
                if removeResult == "airdropMissing" or removeResult == "vehicleExist" then
                    print("[Air Drop] Specific airdrops cleaning, cannot remove, because: " .. removeResult);
                    table.remove(AirdropsData.OldSpecificAirdropsSpawned, i);
                end
            end
        end
    end
end

-- Essa função checa se o chunk do airdrop esta sendo carrepado
-- para poder criar o airdrop
function CheckForCreateAirdrop()
    -- Checa a espera de ticks
    if ticksPerCheck < ticksMax then
        ticksPerCheck = ticksPerCheck + 1;
        return;
    end
    ticksPerCheck = 0;
    -- Verificamos se todos os airdrops já foram spawnados
    if #AirdropsToSpawn == 0 then
        Events.OnTick.Remove(CheckForCreateAirdrop);
        print("[Air Drop] All pending airdrops have been created or removed");
        return;
    end
    -- Precisamos salvar localmente a variavel para não ter atualizações indevidas
    -- durante o check, já que a atualização é feita durane o for
    local localAirdropsToSpawn = deepcopy(AirdropsToSpawn);
    for i = 1, #localAirdropsToSpawn do
        -- Recebemos a posicao de spawn
        local spawnIndex = localAirdropsToSpawn[i];
        -- Se não existe um OldAirdrops para excluir então continue
        local spawnArea = airdropPositions[spawnIndex];
        -- Recebemos o square
        local square = getCell():getGridSquare(spawnArea.x, spawnArea.y, spawnArea.z)
        -- Verificamos se o square esta sendo carregado
        if square then
            -- We check the existence of old airdrop been deleted
            if not checkRemovingOldAirdropsExistenceBySpawnIndex(spawnIndex) then
                -- Coletamos quaisquer veiculos existentes nessa area
                local previousAirdrop = square:getVehicleContainer();
                if previousAirdrop then
                    -- Check if is any old airdrop
                    if airdrop:getScriptName() == "Base.airdrop" then
                        -- Removemos este airdrop antigo
                        previousAirdrop:permanentlyRemove();
                        -- Removes da lista de spawnados
                        removeElementFromSpawnedAirdropsBySpawnIndex(spawnIndex);
                        removeAirdropFromRemovingAirdropsBySpawnIndex(spawnIndex)
                        removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex);
                        print("[Air Drop] A old airdrop exist in index: " ..
                            spawnIndex .. " removed successfully, spawning the new one");
                    else -- This is not any airdrop but is in the same square...
                        removeElementFromAirdropsToSpawnBySpawnIndex(spawnIndex);
                        print("[Air Drop] Any vehicle exist in the current spawn index: " ..
                            spawnIndex .. " cannot spawn the airdrop, giving up...");
                        return;
                    end
                end
                -- Adicionamos o airdrop no mundo
                -- Notas importantes: addVehicleDebug necessita obrigatoriamente que square tenha
                -- o elemento chunk, não se engane chunk é na verdade o campo de visão do jogador,
                -- ou seja você só pode spawnar um veiculo se o player esta carregando o chunk por perto
                local airdrop = addVehicleDebug("Base.airdrop", IsoDirections.N, nil, square);
                -- Consertamos caso esteja quebrado
                airdrop:repair();
                -- Adicionamos os loots
                spawnAirdropItems(airdrop);

                -- Removemos da nossa lista de AirdropsToSpawn
                removeElementFromAirdropsToSpawnBySpawnIndex(spawnIndex);

                -- Adicionamos o aidrop para lista de SpawnedAirdrops
                addAirdropToSpawnedAirdropsBySpawnIndex(spawnIndex, airdrop);

                if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
                    print(
                        "[Air Drop] Chunk loaded, created new airdrop in X:" .. spawnArea.x .. " Y:" .. spawnArea.y);
                end
            else
                if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
                    print(
                        "[Air Drop] Cannot create the airdrop in X:" ..
                        spawnArea.x .. " Y:" .. spawnArea.y .. " the index is already in removal: " .. spawnIndex);
                end
            end
        else
            -- Debug
            if SandboxVars.AirdropMain.AirdropConsoleDebug then
                print("[Air Drop] Create airdrop: chunk not loaded in index: " .. spawnIndex);
            end
        end
    end
end

-- Função para adicionar um airdrop especifico em uma posição especifica, não usada durante
-- o mod, usado apenas em outros mods que necessitam spawnar um airdrop
-- spawnArea recebe como parametro x = int, y = int, z = int, despawnam de acordo com a configuração atual
function SpawnSpecificAirdrop(spawnArea)
    local square = getCell():getGridSquare(spawnArea.x, spawnArea.y, spawnArea.z);

    -- Verificamos se o square é valido
    if square then
        -- Criamos o veiculo no mundo, mais info olhe CheckForCreateAirdrop
        local airdrop = addVehicleDebug("Base.airdrop", IsoDirections.N, nil, square);
        -- Consertamos caso esteja quebrado
        airdrop:repair();
        -- Adicionamos os loots
        spawnAirdropItems(airdrop);
        table.insert(AirdropsData.SpecificAirdropsSpawned,
            { spawnArea = spawnArea, ticksToDespawn = SandboxVars.AirdropMain.AirdropRemovalTimer });
        -- Printa no console
        if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
            print("[Air Drop] Specific Airdrop Spawned in X:" ..
                spawnArea.x .. " Y: " .. spawnArea.y);
        end
    else
        print("[Air Drop] Specific Airdrop: Cannot spawn the square is invalid in X: " ..
            spawnArea.x .. " Y: " .. spawnArea.y);
    end
end

-- A cada hora dentro do jogo verifica se vai ter air drop
Events.EveryHours.Add(CheckAirdrop);

-- Carregamos os dados
Events.OnInitGlobalModData.Add(function(isNewGame)
    AirdropsData = ModData.getOrCreate("serverAirdropsData");
    -- Null Check
    if not AirdropsData.OldAirdrops then AirdropsData.OldAirdrops = {} end
    if not AirdropsData.SpecificAirdropsSpawned then AirdropsData.SpecificAirdropsSpawned = {} end
    if not AirdropsData.OldSpecificAirdropsSpawned then AirdropsData.OldSpecificAirdropsSpawned = {} end

    if not SandboxVars.AirdropMain.AirdropDisableOldDespawn then
        -- Iterar sobre SpecificAirdropsSpawned
        for i, specificAirdrop in ipairs(AirdropsData.SpecificAirdropsSpawned) do
            local found = false
            -- Iterar sobre OldSpecificAirdropsSpawned
            for j, oldAirdrop in ipairs(AirdropsData.OldSpecificAirdropsSpawned) do
                if specificAirdrop.spawnArea == oldAirdrop.spawnArea then
                    found = true
                    break
                end
            end

            -- Se não encontrou correspondência, adiciona o item a OldSpecificAirdropsSpawned
            if not found then
                table.insert(AirdropsData.OldSpecificAirdropsSpawned, specificAirdrop)
            end
        end
    end

    -- Carrega todas as configurações
    readAirdropsPositions();
    readAirdropsLootTable();

    -- Limpador de airdrop antigo
    if not SandboxVars.AirdropMain.AirdropDisableOldDespawn then
        print("[Air Drop] Waiting for the first player connect to start removing old air drops")
        AirdropsData.RemovingOldAirdrops = deepcopy(AirdropsData.OldAirdrops);
        Events.OnTick.Add(ForceDespawnAirdrops);
    end
end)
