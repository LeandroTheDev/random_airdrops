---@diagnostic disable: undefined-global, deprecated
-- By bobodev o brabo tem nome 😊😊

-- Variaveis de performance
-- aguardamos tal tick para fazer o check de airdrops para spawnar/despawnar
local ticksPerCheck = 0;
local ticksPerCheckDespawn = 0;
local ticksMax = SandboxVars.AirdropMain.AirdropTickCheck;
local giveUpDespawn = 0;

-- Lua Utils

-- Clona a tabela inteira
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

-- Guarda localmente todas as posições que podem nascer airdrop
local airdropPositions = {};
-- Guarda localmente todos os items para spawnar no airdrop
local airdropLootTable = {};
-- Guarda globalmente todos os airdrops já spawnados
-- para futuramente serem excluidos
-- airdrop = BaseVehicle / Literalmente o airdrop / sera nulo quando o airdrop ainda não foi criado!!!
-- ticksToDespawn = int / quadno esta variavel chegar a 0 o airdrop sera excluido na funcao DespawnAirdrops
-- index = int / é o index do airdropPositions, usamos para verificar se ja foi spawnado naquela área / spawnIndex
SpawnedAirdrops = {};
-- Guarda globalmente os airdrops que ainda vão spawnar mas não foram spawnadows porque ninguem carregou o chunk
-- essa variavel é utilizada sempre que for diferente de 0 para verificar se algum player esta
-- carregando o chunk
-- possui apenas o elemento index do airdropPositions / spawnIndex
AirdropsToSpawn = {};
-- Guarda os dados do mod
-- OldAirdrops = List<spawnIndex> / old airdrops são todos aqueles airdrops que persistiram no mundo após servidor fechar
-- OldAirdropsData = List<SpawnedAirdrops/airdrop==boolean> / dados do old airdrops contem dados apenas se DisableOldDespawn
-- RemovingOldAirdrops = List<spawnIndex> / todos os airdrops que estão sendo removidos no checking, os dados são alocados no inicio do server
AirdropsData = {};

-- Lê as posições do arquivo de configurações
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

-- Lê os items do arquivo de configurações
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

-- Checa se tem players proximo ao airdrop recebido como parametro
local function checkPlayersAround(airdrop)
    -- Obtemos a coordenada do airdrop
    local airdropX = airdrop:getX();
    local airdropY = airdrop:getY();
    local airdropZ = airdrop:getZ();

    -- Coleta o grid
    local square = getCell():getGridSquare(airdropX, airdropY, airdropZ);

    -- Se o grid existe é porque tem um jogador carregando o chunk
    if square then
        print("[Air Drop] Cannot despawn airdrop, a player is rendering close");
        return true;
    else
        return false
    end
end

-- Recebe o airdrop como parametro e adiciona itens a ele
local function spawnAirdropItems(airdrop)
    -- se tu entender como isso funciona... te dou 10 conto no pix (mentira)
    -- Coletamos o container do airdrop
    local airdropContainer = airdrop:getPartById("TruckBed"):getItemContainer();

    -- Para o atributo id, id's de elementos que estejam aqui dentro são ignorados
    local idSpawneds = {};

    local alocatedSelectedType
    -- Varre a lista e chama as funções a partir do type
    -- as funcoes precisam ser colocadas como parametro
    -- pois as funcoes sao referenciadas depois de listSpawn
    local function listSpawn(list, selectType)
        alocatedSelectedType = selectType;
        -- Varremos todos os elementos do loot table
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
        -- Precisamos criar uma template table porque listSpawn so aceita lista kkk sou burror
        -- e estamos inserindo apenas o elemento então temos uma tabela com o elemento dentro
        alocatedSelectedType(child[selectedIndex]);
    end

    local function selectType(element)
        local jump = false;
        -- Checamos se a variavel id existe
        if element.id then
            -- Verificamos se o id ja foi adicionado
            if idSpawneds[element.id] then jump = true end
        end
        -- Checa se chance é nulo
        if not element.chance then element.chance = 100 end
        -- Verificamos se não precisa pular
        if not jump then
            -- Verificamos o tipo
            if element.type == "combo" then
                -- Verifica se o elemento tem id
                if element.id then
                    -- Se tiver adicione a tabela de id spawnados
                    idSpawneds[element.id] = true;
                end
                -- Verificamos se quantity não é nulo
                if element.quantity then
                    -- Adicionamos conforme a quantidade
                    for _ = 1, element.quantity do
                        -- Verificamos a chance pra spawnar o child
                        if ZombRand(100) + 1 <= element.chance then
                            -- Adicionamos o item
                            spawnCombo(element.child);
                        end
                    end
                else
                    -- Verificamos a chance pra spawnar o child
                    if ZombRand(100) + 1 <= element.chance then
                        -- Adicionamos o item
                        spawnCombo(element.child);
                    end
                end
            elseif element.type == "item" then
                -- Verifica se o elemento tem id
                if element.id then
                    -- Se tiver adicione a tabela de id spawnados
                    idSpawneds[element.id] = true;
                end
                -- Verificamos se quantity não é nulo
                if element.quantity then
                    -- Adicionamos conforme a quantidade
                    for _ = 1, element.quantity do
                        -- Verificamos a chance pra spawnar o child
                        if ZombRand(100) + 1 <= element.chance then
                            -- Adicionamos o item
                            spawnItem(element.child);
                        end
                    end
                else
                    -- Verificamos a chance pra spawnar o child
                    if ZombRand(100) + 1 <= element.chance then
                        -- Adicionamos o item
                        spawnItem(element.child);
                    end
                end
            elseif element.type == "oneof" then
                -- Verifica se o elemento tem id
                if element.id then
                    -- Se tiver adicione a tabela de id spawnados
                    idSpawneds[element.id] = true;
                end
                -- Verificamos se quantity não é nulo
                if element.quantity then
                    -- Adicionamos conforme a quantidade
                    for _ = 1, element.quantity do
                        -- Verificamos a chance pra spawnar o child
                        if ZombRand(100) + 1 <= element.chance then
                            -- Adicionamos o item
                            spawnOneof(element.child);
                        end
                    end
                else
                    -- Verificamos a chance pra spawnar o child
                    if ZombRand(100) + 1 <= element.chance then
                        -- Adicionamos o item
                        spawnOneof(element.child);
                    end
                end
            end
        end
    end

    -- Iniciamos o spawn de loot
    listSpawn(airdropLootTable, selectType);
end

-- Remove o elemento da variavel AirdropsToSpawn pelo spawnIndex
local function removeElementFromAirdropsToSpawnBySpawnIndex(spawnIndex)
    -- Varredura nos AirdropsToSpawn
    for i = 1, #AirdropsToSpawn do
        -- Verifica se o spawnIndex é o mesmo do AirdropsToSpawn
        if spawnIndex == AirdropsToSpawn[i] then
            -- Remove da tabela
            table.remove(AirdropsToSpawn, i);
            break;
        end
    end
end

-- Remove o elemento da variavel SpawnedAirdrops pelo spawnIndex
local function removeElementFromSpawnedAirdropsBySpawnIndex(spawnIndex)
    -- Varredura nos AirdropsToSpawn
    for i = 1, #SpawnedAirdrops do
        -- Verifica se o spawnIndex é o mesmo do SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Remove da tabela
            table.remove(SpawnedAirdrops, i);
            break;
        end
    end
end

-- Remove o elemento da variavel SpawnedAirdrops pelo spawnIndex
local function removeElementFromOldAirdropsDataBySpawnIndex(spawnIndex)
    -- Varredura nos AirdropsToSpawn
    for i = 1, #AirdropsData.OldAirdropsData do
        -- Verifica se o spawnIndex é o mesmo do SpawnedAirdrops
        if spawnIndex == AirdropsData.OldAirdropsData[i].index then
            -- Remove da tabela
            table.remove(AirdropsData.OldAirdropsData, i);
            break;
        end
    end
end

-- Reduz o ticksToDespawn baseado no spawnIndex
local function reduceTicksToDespawnFromSpawnedAirdropsBySpawnIndex(spawnIndex)
    -- Varredura nos AirdropsToSpawn
    for i = 1, #SpawnedAirdrops do
        -- Verifica se o spawnIndex é o mesmo do SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Reduz da tabela
            SpawnedAirdrops[i].ticksToDespawn = SpawnedAirdrops[i].ticksToDespawn - 1;
            break;
        end
    end
end

-- Reduz o ticksToDespawn baseado no spawnIndex
local function reduceTicksToDespawnFromOldAirdropsDataBySpawnIndex(spawnIndex)
    -- Varredura nos AirdropsToSpawn
    for i = 1, #AirdropsData.OldAirdropsData do
        -- Verifica se o spawnIndex é o mesmo do SpawnedAirdrops
        if spawnIndex == AirdropsData.OldAirdropsData[i].index then
            -- Reduz da tabela
            AirdropsData.OldAirdropsData[i].ticksToDespawn = AirdropsData.OldAirdropsData[i].ticksToDespawn - 1;
            break;
        end
    end
end

-- Adiciona o aidrop no SpawnedAirdrops baseado no spawnIndex
local function addAirdropToSpawnAirdropsBySpawnIndex(spawnIndex, airdrop)
    -- Varredura nos SpawnedAirdrops
    for i = 1, #SpawnedAirdrops do
        -- Verifica se o spawnIndex é o mesmo do SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Adicionamos o airdrop a lista de SpawnedAirdrops
            SpawnedAirdrops[i].airdrop = airdrop;
            -- Adicionamos o id do airdrop a lista de OldAirdrops
            table.insert(AirdropsData.OldAirdrops, spawnIndex);
            break;
        end
    end
end

-- Adiciona o aidrop no SpawnedAirdrops baseado no spawnIndex
local function addTrueToOldAirdropsDataBySpawnIndex(spawnIndex)
    -- Varredura nos SpawnedAirdrops
    for i = 1, #AirdropsData.OldAirdropsData do
        -- Verifica se o spawnIndex é o mesmo do OldAirdropsData
        if spawnIndex == AirdropsData.OldAirdropsData[i].index then
            -- Colocamos para true
            AirdropsData.OldAirdropsData[i].airdrop = true;
            break;
        end
    end
end

-- Remove o da lista de OldAirdrops pelo Id do airdrop
local function removeAirdropFromOldAirdropsBySpawnIndex(spawnIndex)
    -- Varredura nos OldAirdrops
    for i = 1, #AirdropsData.OldAirdrops do
        -- Verifica se o id é o mesmo do OldAirdrops
        if spawnIndex == AirdropsData.OldAirdrops[i] then
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

-- Verifica atraves do spawnIndex se existe um OldAirdrops naquela posição
local function checkOldAirdropsExistenceBySpawnIndex(spawnIndex)
    -- Varredura nos OldAirdrops
    for i = 1, #AirdropsData.OldAirdrops do
        -- Verifica se o id é o mesmo do OldAirdrops
        if spawnIndex == AirdropsData.OldAirdrops[i] then
            -- Então existe sim um OldAirdrops
            return true;
        end
    end
    -- Não existe nenhum OldAirdrops
    return false;
end

-- Verifica a existencia do index em SpawnedAirdrops
local function checkSpawnAirdropsExistenceBySpawnIndex(spawnIndex)
    -- Varredura SpawnedAirdrops
    for i = 1, #SpawnedAirdrops do
        -- Verifica se o id é o mesmo do SpawnedAirdrops
        if spawnIndex == SpawnedAirdrops[i].index then
            -- Então existe sim o Index
            return true;
        end
    end
    -- Não existe nenhum Index
    return false;
end

-- Checa se é vai spawnar um airdrop
function CheckAirdrop()
    -- Fazemos um check para despawnar os Airdrops Anteriores
    if not SandboxVars.AirdropMain.AirdropDisableDespawn then
        DespawnAirdrops();
    end
    -- Checa se vai ter um airdrop nesta chamada 5% de chance
    if ZombRand(100) + 1 <= SandboxVars.AirdropMain.AirdropFrequency then
        -- Spawna uma unidade de airdrop
        local airdropLocationName = SpawnAirdrop();
        -- Verificamos se ele de fato spawnou um airdrop
        -- afinal em casos de erros ele não ira spawnar
        if not airdropLocationName then return end;
        -- Obtém a lista de jogadores online
        local players = getOnlinePlayers();
        -- Compatibilidade com singleplayer
        if not players then
            -- Texto do Som para emitir ao jogador
            local alarmSound = "airdrop" .. tostring(ZombRand(1));
            -- Alocamos o som que vai sair
            local sound = getSoundManager():PlaySound(alarmSound, false, 0);
            -- Soltamos o som parao  jogador
            getSoundManager():PlayAsMusic(alarmSound, sound, false, 0);
            sound:setVolume(0.1);
        else -- Caso contrario é um servidor prossiga normal
            -- Alertamos todos os jogadores que um airdrop foi spawnado
            for i = 0, players:size() - 1 do
                -- Obtém o jogador pelo índice
                local player = players:get(i)
                -- Emite o alerta ao jogador
                sendServerCommand(player, "ServerAirdrop", "alert", { name = airdropLocationName });
            end
        end
    else
        print("[Air Drop] Global airdrop check no");
    end
end

-- Spawna um airdrop ao mundo aleatoriamente
function SpawnAirdrop()
    local spawnIndex = 0;

    -- Seleciona aleatoriamente uma area de spawn que não foi spawnada ainda
    local tries = 20;
    while tries > 0 do
        -- Checa se airdropPositions é vazio
        if #airdropPositions == 0 then
            tries = 0; break;
        end
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

-- Exclui todos os airdrops que estão setenciados
-- a não ser que tenha jogadores proximos ai ele não exclui
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
                -- Agora precisamos das tabelas
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
    -- Verificamos se OldAirdrops esta vazio
    if #AirdropsData.RemovingOldAirdrops == 0 then
        --Remove o evento
        Events.OnTick.Remove(ForceDespawnAirdrops);
        print("[Air Drop] Finished cleaning the old air drops")
    end
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
                if airdrop:getScriptName() == "Base.SurvivorSupplyDrop" then
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
end

-- Essa função checa se o chunk do airdrop esta sendo carrepado
-- para poder criar o airdrop
function CheckForCreateAirdrop()
    -- Checa a espera de ticks
    if ticksPerCheck < ticksMax then
        ticksPerCheck = ticksPerCheck + 1;
        return
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
        if not checkOldAirdropsExistenceBySpawnIndex(spawnIndex) then
            local spawnArea = airdropPositions[spawnIndex];
            -- Recebemos o square
            local square = getCell():getGridSquare(spawnArea.x, spawnArea.y, spawnArea.z)
            -- Verificamos se o square esta sendo carregado
            if square then
                -- Adicionamos o airdrop no mundo
                -- Notas importantes: addVehicleDebug necessita obrigatoriamente que square tenha
                -- o elemento chunk, não se engane chunk é na verdade o campo de visão do jogador,
                -- ou seja você só pode spawnar um veiculo se o player esta carregando o chunk por perto
                local airdrop = addVehicleDebug("Base.SurvivorSupplyDrop", IsoDirections.N, nil, square);
                -- Consertamos caso esteja quebrado
                airdrop:repair();
                -- Adicionamos os loots
                spawnAirdropItems(airdrop);

                -- Removemos da nossa lista de AirdropsToSpawn
                removeElementFromAirdropsToSpawnBySpawnIndex(spawnIndex);

                -- Adicionamos o aidrop para lista de SpawnedAirdrops
                addAirdropToSpawnAirdropsBySpawnIndex(spawnIndex, airdrop)

                -- Precisamos verificar se DisableOldDespawn esta ativo
                -- para podermos adicionar dizer que airdrop é true na lista de OldAirdropsData
                if SandboxVars.AirdropMain.AirdropDisableOldDespawn then
                    -- Colocamos para true
                    addTrueToOldAirdropsDataBySpawnIndex(spawnIndex);
                end

                if SandboxVars.AirdropMain.AirdropConsoleDebugCoordinates then
                    print(
                        "[Air Drop] Chunk loaded, created new airdrop in X:" .. spawnArea.x .. " Y:" .. spawnArea.y);
                end
            else
                -- Debug
                if SandboxVars.AirdropMain.AirdropConsoleDebug then
                    print("[Air Drop] Create airdrop: chunk not loaded in index: " .. spawnIndex);
                end
            end
        else
            print("[Air drop] Cannot create the airdrop old airdrop still spawned in: " .. spawnIndex)
        end
    end
end

-- A cada hora dentro do jogo verifica se vai ter air drop
Events.EveryHours.Add(CheckAirdrop);

-- Carregamos os dados
Events.OnInitGlobalModData.Add(function(isNewGame)
    AirdropsData = ModData.getOrCreate("serverAirdropsData");
    -- Null Check
    if not AirdropsData.OldAirdrops then AirdropsData.OldAirdrops = {} end
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
