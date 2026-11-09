--!nonstrict
-- Persistent player profiles (DataStoreService): coins, achievements, lifetime documents,
-- endings, flashlight skins, settings, stats and the host's saved run (checkpoint save).
-- Works offline in Studio when API access is disabled (session-only data + warning).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local Documents = require(Shared.Documents)
local Net = require(Shared.Net)

local Data = {}
local profiles: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}
local store: DataStore? = nil
local storeAvailable = false

local function defaultProfile()
	return {
		v = 1,
		coins = 0,
		achievements = {},
		docs = {},
		endings = {},
		skins = { classic = true },
		skin = "classic",
		settings = table.clone(Config.DefaultSettings),
		stats = { runs = 0, deaths = 0, escapes = 0, wins = 0 },
		run = nil,
	}
end

local function reconcile(profile)
	local template = defaultProfile()
	for key, value in template do
		if profile[key] == nil then
			profile[key] = value
		end
	end
	for key, value in Config.DefaultSettings do
		if profile.settings[key] == nil then
			profile.settings[key] = value
		end
	end
	for key, value in template.stats do
		if profile.stats[key] == nil then
			profile.stats[key] = value
		end
	end
	profile.skins.classic = true
	return profile
end

function Data.Get(player: Player)
	return profiles[player]
end

function Data.IsLoaded(player: Player): boolean
	return loaded[player] == true
end

function Data.Sync(player: Player)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	Net.Event("Profile"):FireClient(player, {
		coins = profile.coins,
		achievements = profile.achievements,
		docs = profile.docs,
		endings = profile.endings,
		skins = profile.skins,
		skin = profile.skin,
		settings = profile.settings,
		stats = profile.stats,
		hasSave = profile.run ~= nil,
		saveMission = profile.run and profile.run.mission or nil,
		online = storeAvailable,
	})
end

function Data.Load(player: Player)
	local profile = nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync("player_" .. player.UserId)
			end)
			if ok then
				profile = result
				break
			end
			warn(string.format("[Data] load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
			task.wait(attempt)
		end
	end
	if typeof(profile) ~= "table" then
		profile = defaultProfile()
	end
	profiles[player] = reconcile(profile)
	loaded[player] = true
	Data.Sync(player)
end

function Data.Save(player: Player)
	local profile = profiles[player]
	if not profile or not store or not loaded[player] then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function()
			return profile
		end)
	end)
	if not ok then
		warn("[Data] save failed for", player.Name, err)
	end
end

function Data.Award(player: Player, id: string)
	local profile = profiles[player]
	local def = Progression.Achievements[id]
	if not profile or not def or profile.achievements[id] then
		return
	end
	profile.achievements[id] = os.time()
	profile.coins += def.coins or 0
	for skinId, skin in Progression.Skins do
		if skin.unlock == id then
			profile.skins[skinId] = true
		end
	end
	Net.Event("Achievement"):FireClient(player, id)
	Data.Sync(player)
end

function Data.MarkDoc(player: Player, docId: string)
	local profile = profiles[player]
	if not profile or not Documents[docId] or profile.docs[docId] then
		return
	end
	profile.docs[docId] = true
	local count = 0
	for _ in profile.docs do
		count += 1
	end
	if count >= Config.TotalDocuments then
		Data.Award(player, "archivist")
	end
	Data.Sync(player)
end

function Data.Stat(player: Player, name: string, delta: number)
	local profile = profiles[player]
	if profile then
		profile.stats[name] = (profile.stats[name] or 0) + delta
	end
end

function Data.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.coins += math.floor(amount)
		Data.Sync(player)
	end
end

function Data.MarkEnding(player: Player, endingId: string)
	local profile = profiles[player]
	if profile then
		profile.endings[endingId] = true
	end
end

function Data.SaveRun(player: Player, snapshot)
	local profile = profiles[player]
	if profile then
		profile.run = snapshot
	end
end

function Data.ClearRun(player: Player)
	local profile = profiles[player]
	if profile then
		profile.run = nil
	end
end

local function sanitizeSettings(incoming)
	local clean = {}
	if typeof(incoming) ~= "table" then
		return clean
	end
	for key, default in Config.DefaultSettings do
		local value = incoming[key]
		if value ~= nil and typeof(value) == typeof(default) then
			if typeof(value) == "number" then
				if value ~= value then
					continue -- NaN
				end
				local range = Config.SettingRanges[key]
				if range then
					value = math.clamp(value, range[1], range[2])
				end
			elseif typeof(value) == "string" then
				if key == "cameraMode" and value ~= "first" and value ~= "third" then
					continue
				end
			end
			clean[key] = value
		end
	end
	return clean
end

function Data.Init(onSkinChanged: ((Player) -> ())?)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		-- probe once so Studio without API access degrades gracefully
		local probeOk = pcall(function()
			store:GetAsync("probe")
		end)
		storeAvailable = probeOk
		if not probeOk then
			store = nil
			warn("[Data] DataStore unavailable (enable 'Studio Access to API Services' to test saving). Using session-only data.")
		end
	else
		warn("[Data] DataStore unavailable:", result)
	end

	Players.PlayerAdded:Connect(Data.Load)
	for _, player in Players:GetPlayers() do
		task.spawn(Data.Load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Data.Save(player)
		profiles[player] = nil
		loaded[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not storeAvailable then
			return
		end
		local threads = {}
		for _, player in Players:GetPlayers() do
			table.insert(threads, task.spawn(Data.Save, player))
		end
		task.wait(2)
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				task.spawn(Data.Save, player)
			end
		end
	end)

	Net.Event("Settings").OnServerEvent:Connect(function(player, incoming)
		if not Net.Allow(player, "settings", 0.5) then
			return
		end
		local profile = profiles[player]
		if not profile then
			return
		end
		for key, value in sanitizeSettings(incoming) do
			profile.settings[key] = value
		end
	end)

	Net.Event("EquipSkin").OnServerEvent:Connect(function(player, skinId)
		if typeof(skinId) ~= "string" or not Net.Allow(player, "skin", 0.5) then
			return
		end
		local profile = profiles[player]
		if profile and profile.skins[skinId] and Progression.Skins[skinId] then
			profile.skin = skinId
			Data.Sync(player)
			if onSkinChanged then
				onSkinChanged(player)
			end
		end
	end)
end

return Data
