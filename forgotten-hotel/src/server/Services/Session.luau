--!nonstrict
-- Session flow: lobby (host, ready-up, difficulty, continue, private runs), run start,
-- drop-in joining, story hooks for every mission, the final choice, escape, endings,
-- rewards, run saving and resetting the world for the next run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local Run = require(script.Parent.Run)
local Data = require(script.Parent.Data)
local Inventory = require(script.Parent.Inventory)
local Pickups = require(script.Parent.Pickups)
local Doors = require(script.Parent.Doors)
local Power = require(script.Parent.Power)
local Hiding = require(script.Parent.Hiding)
local Puzzles = require(script.Parent.Puzzles)
local Survival = require(script.Parent.Survival)
local Missions = require(script.Parent.Missions)
local Elevator = require(script.Parent.Elevator)
local Interact = require(script.Parent.Interact)
local Events = require(script.Parent.Events)

local Hotel = require(script.Parent.Parent.Map.Hotel)
local Monsters = require(script.Parent.Parent.Monsters.Monsters)

local Session = {}
Session.Host = nil :: Player?
Session.Ready = {} :: { [Player]: boolean }
Session.FinalChosen = false
Session.EndingStarted = false
local lastPositions: { [Player]: Vector3 } = {}

----------------------------------------------------------------------------------------
-- Lobby state broadcast
----------------------------------------------------------------------------------------

function Session.Broadcast()
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, {
			userId = player.UserId,
			name = player.DisplayName,
			ready = Session.Ready[player] == true,
			inRun = Run.Participants[player] == true,
		})
	end
	local host = Session.Host
	local hostProfile = host and Data.Get(host)
	Net.Event("RunState"):FireAllClients({
		state = Run.State,
		host = host and host.UserId or 0,
		difficulty = Run.Difficulty,
		players = list,
		mission = Missions.Index,
		canContinue = hostProfile ~= nil and hostProfile.run ~= nil,
		continueMission = hostProfile and hostProfile.run and hostProfile.run.mission or nil,
		privateServer = game.PrivateServerId ~= "",
	})
end

local function pickHost()
	if Session.Host and Session.Host.Parent then
		return
	end
	Session.Host = Players:GetPlayers()[1]
end

----------------------------------------------------------------------------------------
-- World
----------------------------------------------------------------------------------------

local function applyLighting()
	Lighting.ClockTime = 0.4
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(16, 14, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(36, 40, 54)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0
	Lighting.GeographicLatitude = 30
	local function ensure(className: string, name: string)
		local obj = Lighting:FindFirstChild(name)
		if not obj then
			obj = Instance.new(className)
			obj.Name = name
			obj.Parent = Lighting
		end
		return obj
	end
	local atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(70, 80, 100)
	atmosphere.Decay = Color3.fromRGB(30, 26, 36)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	local cc = ensure("ColorCorrectionEffect", "Grade")
	cc.Saturation = -0.28
	cc.Contrast = 0.14
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(232, 236, 255)
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.6
	local sky = Lighting:FindFirstChildOfClass("Sky") or ensure("Sky", "NightSky")
	sky.StarCount = 400
	sky.MoonAngularSize = 14
	sky.CelestialBodiesShown = true
end
Session.ApplyLighting = applyLighting

function Session.BuildWorld()
	Doors.Reset()
	Pickups.Reset()
	Hiding.Reset()
	Puzzles.Reset()
	Power.Reset()
	Missions.Reset()
	Events.Reset()
	Hotel.Build()
	Power.Scan()
	Monsters.Reset()
	applyLighting()
	Session.RegisterTriggers()
end

----------------------------------------------------------------------------------------
-- Run lifecycle
----------------------------------------------------------------------------------------

local function enroll(player: Player)
	Run.Participants[player] = true
	if not Inventory.Data[player] then
		Inventory.Clear(player)
	end
	Survival.ResetPlayer(player)
	Hiding.Clear(player)
end

function Session.StartRun(save)
	if Run.State ~= "Lobby" then
		return
	end
	Run.ResetState()
	if save and Config.Difficulty[save.difficulty] then
		Run.Difficulty = save.difficulty
	end
	Run.SetState("Playing")
	Run.StartTime = os.clock()
	Run.Checkpoint = Run.Point("Courtyard")
	Session.FinalChosen = false
	Session.EndingStarted = false
	for _, player in Players:GetPlayers() do
		Inventory.Clear(player)
		enroll(player)
		Data.Stat(player, "runs", 1)
		Survival.SendToCheckpoint(player)
	end
	Doors.Unlock("FrontDoor")
	Doors.SetOpen("FrontDoor", true, nil, {})
	Monsters.SetConcierge(true)
	Monsters.SetShadowMode("off")
	if save then
		for id in save.docs or {} do
			Run.Docs[id] = true
		end
		if Session.Host then
			Inventory.Load(Session.Host, save.items)
		end
		Run.Notify(nil, "استُعيدت الجولة من آخر نقطة حفظ.", "info")
		Missions.Restore(math.clamp(save.mission or 1, 1, 10))
		for _, player in Players:GetPlayers() do
			Survival.SendToCheckpoint(player)
		end
	else
		Missions.Start(1)
	end
	Session.Ready = {}
	Session.Broadcast()
end

function Session.JoinRun(player: Player)
	if Run.State ~= "Playing" or Run.Participants[player] then
		return
	end
	enroll(player)
	Data.Stat(player, "runs", 1)
	Survival.SendToCheckpoint(player)
	Missions.Broadcast(player)
	Run.Notify(nil, player.DisplayName .. " سجّل وصوله.", "info")
	Session.Broadcast()
end

local function saveRunFor(player: Player, missionIndex: number)
	Data.SaveRun(player, {
		mission = missionIndex,
		difficulty = Run.Difficulty,
		items = Inventory.Snapshot(player),
		docs = table.clone(Run.Docs),
		savedAt = os.time(),
	})
end

function Session.Reset()
	Run.SetState("Lobby")
	Run.ResetState()
	Session.Ready = {}
	Session.FinalChosen = false
	Session.EndingStarted = false
	for _, player in Players:GetPlayers() do
		Inventory.Clear(player)
	end
	Session.BuildWorld()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
	Session.Broadcast()
end

function Session.EndRun(endingId: string)
	if Session.EndingStarted then
		return
	end
	Session.EndingStarted = true
	Run.SetState("Ending")
	Monsters.SetShadowMode("off")
	Monsters.SetConcierge(false)
	local diff = Run.Diff()
	local elapsed = os.clock() - Run.StartTime
	local docs = Run.DocCount()
	for player in Run.Participants do
		if player.Parent then
			local coins = math.floor((Config.Rewards[endingId] or 0) * diff.reward + docs * Config.Rewards.perDocument)
			local untouched = not Run.DownedThisRun[player]
			Data.AddCoins(player, coins)
			Data.Award(player, endingId)
			Data.MarkEnding(player, endingId)
			Data.Stat(player, "wins", 1)
			local character = player.Character
			if character and character:GetAttribute("Escaped") then
				Data.Stat(player, "escapes", 1)
			end
			if Run.Difficulty == "Nightmare" then
				Data.Award(player, "insomniac")
			end
			if untouched then
				Data.Award(player, "untouchable")
			end
			Data.ClearRun(player)
			Net.Event("Ending"):FireClient(player, endingId, {
				coins = coins,
				documents = docs,
				time = math.floor(elapsed),
				difficulty = Run.Difficulty,
				untouched = untouched,
				escaped = character ~= nil and character:GetAttribute("Escaped") == true,
			})
			task.spawn(Data.Save, player)
		end
	end
	Session.Broadcast()
	task.delay(30, Session.Reset)
end

----------------------------------------------------------------------------------------
-- Final choice + escape
----------------------------------------------------------------------------------------

local ENDING_FOR = { seal = "escape", destroy = "liberation", wake = "secret" }

local function finalOptions()
	local hasLocket = Inventory.Holder("Locket") ~= nil
	local options = {
		{ id = "seal", title = "اختم القلب", desc = "اختم القلب واهرب عبر نفق الخدمة." },
		{
			id = "destroy",
			title = "دمّر القلب",
			desc = hasLocket and "أعطِ القلب قلادة لينا - الشيء الذي أخذه وأحبّه." or "يتطلب قلادة لينا (غرفة الأطفال في 307).",
			disabled = not hasLocket,
		},
		{ id = "keep", title = "خذ المفتاح الرئيسي", desc = "كن حارس الفندق. إلى الأبد." },
	}
	if hasLocket and Run.DocCount() >= Config.TotalDocuments then
		table.insert(options, 3, { id = "wake", title = "اقرأ لها القصة", desc = "وُجدت كل الصفحات. ضعها أمام القلب.", secret = true })
	end
	return options
end

function Session.StartEscape(choice: string, player: Player)
	local refs = Hotel.Refs
	Run.SetFlag("finalChoice", choice)
	if refs.Console then
		refs.Console.Text = choice == "seal" and "تم ختم القلب\nأخلوا المكان" or "!!! انهيار النواة !!!\nأخلوا المكان"
	end
	if choice == "destroy" or choice == "wake" then
		Inventory.Remove(Inventory.Holder("Locket") or player, "Locket", 1)
		refs.HeartDead = true
		if refs.HeartCore then
			refs.HeartCore.Color = Color3.fromRGB(255, 240, 230)
			Sounds.Play("Shriek", refs.HeartCore, { Volume = 2 })
		end
		Run.Cinematic(nil, "Scare", { color = Color3.fromRGB(255, 250, 240) })
	else
		refs.HeartDead = true
		if refs.HeartCore then
			refs.HeartCore.Color = Color3.fromRGB(40, 10, 12)
		end
	end
	Run.Cinematic(nil, "Shake", { intensity = 0.8, duration = 2 })
	Power.Emergency("B", true)
	Power.SetZone("Escape", true)
	Doors.Unlock("ExitGate")
	Doors.SetOpen("ExitGate", true, nil, {})
	task.spawn(function()
		while Run.IsPlaying() and Run.Flag("finalChoice") do
			if refs.HeartCore and refs.HeartCore.Parent then
				Sounds.Play("Alarm", refs.HeartCore)
			end
			task.wait(1.6)
		end
	end)
	Run.SetCheckpoint("Lab")
	Run.Notify(nil, "اركض! عبر نفق الخدمة - الجدار الغربي للمختبر!", "danger")
	Run.Cinematic(nil, "Subtitle", { text = "شيء ما يمزّق نفسه ليتحرر من القلب...", duration = 4 })
	task.wait(2.5)
	Monsters.PlaceShadow("escape", refs.EscapeShadowSpawn)
	local escapedCount = 0
	Events.AddZone("Exit", refs.ExitZone, function(escaper)
		local character = escaper.Character
		if not character or character:GetAttribute("Escaped") then
			return
		end
		character:SetAttribute("Escaped", true)
		escapedCount += 1
		Run.Notify(nil, escaper.DisplayName .. " هرب!", "objective")
		if escapedCount == 1 then
			Run.SetFlag("escaped", true)
			task.spawn(function()
				for t = 12, 1, -1 do
					local remaining = 0
					for _, entry in Run.Characters(false) do
						if not entry.character:GetAttribute("Escaped") then
							remaining += 1
						end
					end
					if remaining == 0 then
						break
					end
					if t % 3 == 0 then
						Run.Notify(nil, string.format("النفق ينهار! %d ثانية!", t), "danger")
					end
					task.wait(1)
				end
				Session.EndRun(ENDING_FOR[choice] or "escape")
			end)
		end
	end, { once = false })
end

function Session.FinalChoice(choice: string, player: Player)
	if Session.FinalChosen then
		return
	end
	local valid = false
	for _, option in finalOptions() do
		if option.id == choice and not option.disabled then
			valid = true
		end
	end
	if not valid then
		return
	end
	Session.FinalChosen = true
	Run.Notify(nil, player.DisplayName .. " اتّخذ القرار.", "info")
	if choice == "keep" then
		local refs = Hotel.Refs
		Run.Cinematic(nil, "Subtitle", { text = "«أهلًا بك بين الموظفين»، يقول صوت خلفك مباشرة.", duration = 4, voice = true })
		if Monsters.Concierge and refs.HeartCore then
			local pos = refs.HeartCore.Position
			Monsters.Concierge:Show(CFrame.lookAt(Vector3.new(pos.X + 6, Config.Floors.B, pos.Z + 8), Vector3.new(pos.X, Config.Floors.B, pos.Z + 12)), 6, true)
		end
		task.wait(4)
		Session.EndRun("concierge")
	else
		Session.StartEscape(choice, player)
	end
end

----------------------------------------------------------------------------------------
-- Story hooks
----------------------------------------------------------------------------------------

local function award(id: string)
	for player in Run.Participants do
		if player.Parent then
			Data.Award(player, id)
		end
	end
end

local function participantsWhere(predicate)
	local list = {}
	for _, entry in Run.Characters(true) do
		if predicate(entry.root.Position) then
			table.insert(list, entry.player)
		end
	end
	return list
end

local function registerMissionHooks()
	-- 1. Enter
	Missions.OnComplete("enter", function()
		Run.SetCheckpoint("Lobby")
		award("checked_in")
		task.spawn(Events.EntranceSlam)
	end)
	Missions.OnRestore("enter", function()
		Doors.SetOpen("FrontDoor", false, nil, { instant = true, silent = true })
		Doors.Lock("FrontDoor", "انصفقت الأبواب خلفك. لن تُفتح مرة أخرى.")
		Run.Flags.entered = true
		Run.SetCheckpoint("Lobby")
	end)
	-- 3. Power
	Missions.OnComplete("power", function()
		Run.SetCheckpoint("Lobby")
		award("lights_on")
		task.spawn(Events.PowerOn)
	end)
	Missions.OnRestore("power", function()
		Doors.Unlock("ReceptionOfficeDoor")
		Pickups.RemoveAll("ReceptionKey")
		Pickups.RemoveAll("Fuse")
		Events.PowerOn(true)
	end)
	-- 4. Elevator card
	Missions.OnComplete("elevator_card", function()
		Run.SetCheckpoint("Spur")
		Run.Notify(nil, "أدخل البطاقة في اللوحة داخل المصعد.", "info")
	end)
	Missions.OnRestore("elevator_card", function()
		Puzzles.SolveKeypad("Security")
		Pickups.RemoveAll("ElevatorCard")
		Run.Flags.elevator = true
		Run.SetCheckpoint("Spur")
	end)
	-- 5. Room 307
	Missions.OnStart("room307", function()
		Run.Notify(nil, "فتّش الطابق الثاني. باب المكتبة مسدود... لكن الخادمات عرفن طريقًا آخر.", "info")
	end)
	Missions.OnComplete("room307", function()
		Run.SetCheckpoint("F3Hall")
		task.spawn(Events.MirrorScare)
		task.delay(6, function()
			Monsters.SetShadowMode("roam")
		end)
	end)
	Missions.OnRestore("room307", function()
		Run.Flags.f3Visited = true
		Run.Flags.mirror = true
		Run.Flags.secretRoom = true
		Run.Flags.passage = true
		Doors.RemoveBarricade("LibraryDoor")
		Puzzles.SolveKeypad("ManagerSafe")
		Pickups.RemoveAll("Key307")
		Doors.Unlock("Room307")
		Run.SetCheckpoint("F3Hall")
		Monsters.SetShadowMode("roam")
	end)
	-- 6. Journals
	Missions.OnStart("documents", function()
		Missions.Broadcast()
	end)
	-- 7. Basement
	Missions.OnStart("basement", function()
		task.delay(2, Events.PhoneCall)
	end)
	Missions.OnComplete("basement", function()
		Run.SetCheckpoint("Cloakroom")
	end)
	Missions.OnRestore("basement", function()
		Doors.Unlock("BasementDoor")
		Run.Flags.basementOpen = true
		Run.SetCheckpoint("Cloakroom")
	end)
	-- 8. Generator
	Missions.OnStart("generator", function()
		Monsters.SetShadowMode("basement")
		Events.BasementDark(participantsWhere(function(p)
			return p.Y < -2
		end))
	end)
	Missions.OnComplete("generator", function()
		Power.SetZone("B", true, true)
		Run.SetCheckpoint("Generator")
		task.delay(4, function()
			Monsters.SetShadowMode("roam")
			Run.Cinematic(nil, "Subtitle", { text = "الأضواء تطرده إلى الطوابق العليا... مؤقتًا.", duration = 4 })
		end)
	end)
	Missions.OnRestore("generator", function()
		Run.Flags.generator = true
		Power.SetZone("B", true)
		Run.SetCheckpoint("Generator")
		Monsters.SetShadowMode("roam")
	end)
	-- 9. Laboratory
	Missions.OnComplete("lab", function()
		Run.SetCheckpoint("Lab")
		Events.HeartReveal(participantsWhere(function(p)
			return p.X < -30 and p.Y < -2
		end))
	end)
	Missions.OnRestore("lab", function()
		Puzzles.SolveKeypad("Laboratory")
		Run.Flags.labEntered = true
		Run.SetCheckpoint("Lab")
	end)
	-- 10. Exit: the console offers the final choice
	Missions.OnStart("exit", function()
		Run.Notify(nil, "استخدم لوحة التحكم أمام القلب.", "info")
	end)

	-- save progress for everyone whenever a mission completes
	Missions.Completed:Connect(function(_, index)
		for player in Run.Participants do
			if player.Parent then
				saveRunFor(player, index + 1)
			end
		end
	end)
end

function Session.RegisterTriggers()
	local refs = Hotel.Refs
	Events.AddZone("Lobby", refs.LobbyZone, function()
		Run.SetFlag("entered", true)
	end)
	Events.AddZone("ThirdFloor", refs.F3Zone, function()
		if Run.Flags.f3Visited then
			return
		end
		Run.Flags.f3Visited = true
		task.spawn(Events.ShadowCorridor)
	end)
	Events.AddZone("Laboratory", refs.LabZone, function()
		Run.SetFlag("labEntered", true)
	end, {
		condition = function()
			return Run.Flag("generator") == true
		end,
	})
	Events.AddZone("Room308", refs.Room308Zone, function()
		task.spawn(Events.Room308Opens)
	end, {
		condition = function()
			return Run.Flag("f3Visited") == true
		end,
	})
	-- console prompt
	local console = refs.Console
	if console then
		Interact.Add(console, { text = "استخدم", object = "لوحة تحكم القلب", dist = 9, los = false, hold = 0.6 }, function(player)
			local current = Missions.Current()
			if not current or current.id ~= "exit" then
				Run.Notify(player, "الدخول مرفوض. اللوحة تومض: «أطعمني».", "warn")
				return
			end
			if Session.FinalChosen then
				return
			end
			Net.Event("Choice"):FireClient(player, "final", { options = finalOptions() })
		end)
	end
	-- roomkeeper zones only matter while playing; Suite 203 / nursery are always guarded
end

----------------------------------------------------------------------------------------
-- Init
----------------------------------------------------------------------------------------

local function onLobbyAction(player: Player, action, arg)
	if typeof(action) ~= "string" or not Net.Allow(player, "lobby", 0.3) then
		return
	end
	pickHost()
	local isHost = player == Session.Host
	if action == "Play" then
		if Run.State == "Playing" then
			Session.JoinRun(player)
		elseif Run.State == "Lobby" then
			if #Players:GetPlayers() == 1 then
				Session.StartRun(nil)
			else
				Session.Ready[player] = true
				local all = true
				for _, p in Players:GetPlayers() do
					if not Session.Ready[p] then
						all = false
					end
				end
				if all then
					Session.StartRun(nil)
				end
			end
		end
	elseif action == "Ready" and Run.State == "Lobby" then
		Session.Ready[player] = not Session.Ready[player]
	elseif action == "Difficulty" and isHost and Run.State == "Lobby" then
		if typeof(arg) == "string" and Config.Difficulty[arg] then
			Run.Difficulty = arg
		end
	elseif action == "Start" and isHost and Run.State == "Lobby" then
		Session.StartRun(nil)
		return
	elseif action == "Continue" and isHost and Run.State == "Lobby" then
		local profile = Data.Get(player)
		if profile and profile.run then
			Session.StartRun(profile.run)
			return
		end
	elseif action == "Private" and isHost and Run.State == "Lobby" then
		task.spawn(function()
			local ok, err = pcall(function()
				local code = TeleportService:ReserveServer(game.PlaceId)
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = code
				local party = {}
				for _, p in Players:GetPlayers() do
					if p == player or Session.Ready[p] then
						table.insert(party, p)
					end
				end
				TeleportService:TeleportAsync(game.PlaceId, party, options)
			end)
			if not ok then
				Run.Notify(player, "الجولات الخاصة تتطلب نشر اللعبة (" .. tostring(err) .. ").", "warn")
			end
		end)
	end
	Session.Broadcast()
end

function Session.Init()
	registerMissionHooks()

	Net.Event("Lobby").OnServerEvent:Connect(onLobbyAction)
	Net.Event("Choice").OnServerEvent:Connect(function(player, context, choice)
		if context ~= "final" or typeof(choice) ~= "string" or not Net.Allow(player, "final", 0.5) then
			return
		end
		if not Run.IsPlaying() or not Run.Participants[player] then
			return
		end
		local current = Missions.Current()
		if not current or current.id ~= "exit" then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local console = Hotel.Refs.Console
		if not root or not console or (root.Position - console.Position).Magnitude > 14 then
			return
		end
		task.spawn(Session.FinalChoice, choice, player)
	end)

	Pickups.OnDocument = function(player, docId)
		Data.MarkDoc(player, docId)
	end
	Elevator.Arrived:Connect(function(_, riders)
		for _, player in riders do
			Data.Award(player, "going_up")
		end
	end)
	Doors.Unlocked:Connect(function(id)
		if id == "BasementDoor" then
			Run.SetFlag("basementOpen", true)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		pickHost()
		player.CharacterAdded:Connect(function(character)
			Hiding.Clear(player)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if root then
				task.spawn(function()
					while character.Parent and root.Parent do
						lastPositions[player] = root.Position
						task.wait(1)
					end
				end)
			end
		end)
		task.delay(1, Session.Broadcast)
		if Run.State == "Playing" then
			-- drop-in: they join from the main menu "Play" button
			task.delay(1, function()
				Run.Notify(player, "هناك جولة جارية. اضغط «العب» للانضمام إلى أصدقائك.", "info")
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if Run.IsPlaying() and Run.Participants[player] then
			local pos = lastPositions[player]
			if pos then
				Pickups.DropCritical(player, pos)
			end
		end
		Run.Participants[player] = nil
		Session.Ready[player] = nil
		Inventory.Forget(player)
		Hiding.Clear(player)
		Net.Forget(player)
		lastPositions[player] = nil
		if Session.Host == player then
			Session.Host = nil
			task.defer(function()
				pickHost()
				Session.Broadcast()
			end)
		end
		task.defer(Session.Broadcast)
		-- if the last participant left mid-run, return to the lobby
		task.delay(2, function()
			if Run.IsPlaying() then
				local any = false
				for p in Run.Participants do
					if p.Parent then
						any = true
					end
				end
				if not any then
					Session.Reset()
				end
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		pickHost()
		task.delay(1, Session.Broadcast)
		local _ = player
	end
end

return Session
