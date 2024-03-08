---@diagnostic disable: undefined-global

-- Adiciona um texto ao jogador
local function addLineToChat(message, color, username, options)
	if not isClient() then return end

	if type(options) ~= "table" then
		options = {
			showTime = false,
			serverAlert = false,
			showAuthor = false,
		};
	end

	if type(color) ~= "string" then
		color = "<RGB:1,1,1>";
	end

	if options.showTime then
		local dateStamp = Calendar.getInstance():getTime();
		local dateFormat = SimpleDateFormat.new("H:mm");
		if dateStamp and dateFormat then
			message = color .. "[" .. tostring(dateFormat:format(dateStamp) or "N/A") .. "]  " .. message;
		end
	else
		message = color .. message;
	end

	local msg = {
		getText = function(_)
			return message;
		end,
		getTextWithPrefix = function(_)
			return message;
		end,
		isServerAlert = function(_)
			return options.serverAlert;
		end,
		isShowAuthor = function(_)
			return options.showAuthor;
		end,
		getAuthor = function(_)
			return tostring(username);
		end,
		setShouldAttractZombies = function(_)
			return false
		end,
		setOverHeadSpeech = function(_)
			return false
		end,
	};

	if not ISChat.instance then return; end;
	if not ISChat.instance.chatText then return; end;
	ISChat.addLineInChat(msg, 0);
end

-- Chamado sempre que o servidor retornar um valor para nós
local function OnServerCommand(module, command, arguments)
	-- Alerta de som quando um airdrop cair
	if module == "ServerAirdrop" and command == "alert" then
		-- Texto do Som para emitir ao jogador
		local alarmSound = "airdrop" .. tostring(ZombRand(1));
		-- Alocamos o som que vai sair
		local sound = getSoundManager():PlaySound(alarmSound, false, 0);
		-- Soltamos o som para o jogador
		getSoundManager():PlayAsMusic(alarmSound, sound, false, 0);
		sound:setVolume(0.1);

		-- Mensagem no chat dizendo que esta spawnando
		addLineToChat(getText("IGUI_Airdrop_Incoming") .. ": " .. getText("IGUI_Airdrop_Name_" .. arguments.name),
			"<RGB:" .. "0,255,0" .. ">");
	end
	-- Alerta de som quando jogador usar o sinalizador
	if module == "ServerAirdrop" and command == "smokeflare" then
		-- Texto do Som para emitir ao jogador
		local alarmSound = "smokeflareradio" .. tostring(ZombRand(1));

		-- O som que vai sair
		local sound = getSoundManager():PlaySound(alarmSound, false, 0);
		-- Soltamos o som para o jogador
		getSoundManager():PlayAsMusic(alarmSound, sound, false, 0);
		sound:setVolume(0.4);

		-- Mensagem no chat dizendo que esta spawnando
		addLineToChat(
			getText("IGUI_Airdrop_Smoke_Flare_Message"), "<RGB:" .. "255,0,0" .. ">");
	end
	if module == "ServerAirdrop" and command == "smokeflare_finished" then
		-- Texto do Som para emitir ao jogador
		local alarmSound = "airdrop" .. tostring(ZombRand(1));

		-- O som que vai sair
		local sound = getSoundManager():PlaySound(alarmSound, false, 0);
		-- Soltamos o som para o jogador
		getSoundManager():PlayAsMusic(alarmSound, sound, false, 0);
		sound:setVolume(0.1);

		-- Mensagem no chat dizendo que esta spawnando
		addLineToChat(
			getText("IGUI_Airdrop_Spawned"), "<RGB:" .. "255,0,0" .. ">");
	end
end
Events.OnServerCommand.Add(OnServerCommand)
