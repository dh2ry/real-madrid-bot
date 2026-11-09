--!nonstrict
-- Horror director: zone triggers, randomized horror events (paced by difficulty) and the
-- scripted cinematic sequences of the story.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
local Net = require(Shared.Net)

local Run = require(script.Parent.Run)
local Power = require(script.Parent.Power)
local Doors = require(script.Parent.Doors)
local Elevator = require(script.Parent.Elevator)
local Interact = require(script.Parent.Interact)
local Pickups = require(script.Parent.Pickups)

local Map = script.Parent.Parent.Map
local Monsters = script.Parent.Parent.Monsters

local Events = {}
local triggers = {}

local function hotelRefs()
	return require(Map.Hotel).Refs
end

local function monsters()
	return require(Monsters.Monsters)
end

----------------------------------------------------------------------------------------
-- Zone triggers
----------------------------------------------------------------------------------------

local function inside(zone, pos: Vector3): boolean
	return pos.X >= zone.min.X and pos.X <= zone.max.X and pos.Y >= zone.min.Y and pos.Y <= zone.max.Y and pos.Z >= zone.min.Z and pos.Z <= zone.max.Z
end
Events.Inside = inside

-- callback(player); opts.once (default true), opts.condition()
function Events.AddZone(name: string, zone, callback, opts)
	opts = opts or {}
	triggers[name] = { zone = zone, callback = callback, once = opts.once ~= false, condition = opts.condition, fired = {} }
end

function Events.RemoveZone(name: string)
	triggers[name] = nil
end

local function pollTriggers()
	if not Run.IsPlaying() then
		return
	end
	for name, trig in triggers do
		if trig.condition == nil or trig.condition() then
			for _, entry in Run.Characters(true) do
				if inside(trig.zone, entry.root.Position) and not trig.fired[entry.player] then
					if trig.once then
						triggers[name] = nil
					else
						trig.fired[entry.player] = true
					end
					task.spawn(trig.callback, entry.player)
					break
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Random events
----------------------------------------------------------------------------------------

local WHISPERS = {
	"...ابقَ معنا...",
	"...سجّل وصولك... ولا تغادر أبدًا...",
	"...إنها في 307...",
	"...أطفئ النور...",
	"...إنه يسمع أنفاسك...",
	"...الفندق لا ينسى...",
}

local function randomParticipant()
	local list = Run.Characters(false)
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function offsetAround(pos: Vector3, minR: number, maxR: number): Vector3
	local a = math.random() * math.pi * 2
	local r = minR + math.random() * (maxR - minR)
	return pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local randomEvents = {
	{
		weight = 4,
		run = function(entry)
			Power.Flicker(entry.root.Position, 34, 2 + math.random() * 2)
			Sounds.PlayAt("Static", entry.root.Position + Vector3.new(0, 8, 0), { Looped = false })
			return true
		end,
	},
	{
		weight = 3,
		run = function(entry) -- footsteps circling closer, then nothing
			local start = offsetAround(entry.root.Position, 26, 34)
			task.spawn(function()
				for i = 1, 7 do
					local p = start:Lerp(entry.root.Position, i / 12)
					Sounds.PlayAt("HeavyStep", p, { Volume = 0.6 + i * 0.08 })
					task.wait(0.55)
				end
			end)
			return true
		end,
	},
	{
		weight = 3,
		run = function(entry) -- a door nearby slams or creaks open
			local best = nil
			for _, door in Doors.Registry do
				if door.anchor and not door.locked and not door.barricaded and door.id ~= "FrontDoor" then
					local d = (door.anchor.Position - entry.root.Position).Magnitude
					if d > 7 and d < 40 then
						best = door
						if door.isOpen then
							break
						end
					end
				end
			end
			if not best then
				return false
			end
			if best.isOpen then
				Doors.SetOpen(best, false, nil, { slam = true })
			else
				Doors.SetOpen(best, true, nil, {})
				Sounds.Play("Creak", best.anchor)
			end
			return true
		end,
	},
	{
		weight = 2,
		run = function()
			return Elevator.Ghost()
		end,
	},
	{
		weight = 3,
		run = function(entry)
			Sounds.PlayAt("Whisper", offsetAround(entry.root.Position, 3, 6) + Vector3.new(0, 4, 0))
			Run.Cinematic(entry.player, "Whisper", { text = WHISPERS[math.random(1, #WHISPERS)], quiet = true })
			return true
		end,
	},
	{
		weight = 2,
		run = function(entry) -- a painting falls off the wall
			for _, painting in CollectionService:GetTagged("Painting") do
				if painting:IsA("Model") and not painting:GetAttribute("Fallen") and painting:IsDescendantOf(workspace) then
					local pivot = painting:GetPivot()
					if (pivot.Position - entry.root.Position).Magnitude < 28 then
						painting:SetAttribute("Fallen", true)
						local value = Instance.new("CFrameValue")
						value.Value = pivot
						value.Changed:Connect(function(cf)
							painting:PivotTo(cf)
						end)
						local floorY = Config.Floors[Config.FloorAt(pivot.Position.Y)]
						local target = CFrame.new(pivot.Position.X, floorY + 0.6, pivot.Position.Z) * (pivot - pivot.Position) * CFrame.new(0, 0, -0.8) * CFrame.Angles(math.rad(-75), 0, 0)
						local tween = TweenService:Create(value, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = target })
						tween.Completed:Connect(function()
							value:Destroy()
							Sounds.PlayAt("Crash", target.Position)
						end)
						tween:Play()
						return true
					end
				end
			end
			return false
		end,
	},
	{
		weight = 2,
		run = function(entry) -- a phone rings somewhere
			for _, phone in CollectionService:GetTagged("Phone") do
				local base = phone:FindFirstChild("Base")
				if base and (base.Position - entry.root.Position).Magnitude < 70 and not Events.PhoneBusy then
					task.spawn(function()
						for _ = 1, 4 do
							Sounds.Play("PhoneRing", base)
							task.wait(1.4)
						end
					end)
					return true
				end
			end
			return false
		end,
	},
	{
		weight = 1,
		run = function(entry)
			Sounds.PlayAt("Scream", offsetAround(entry.root.Position, 60, 80), { Volume = 0.8 })
			return true
		end,
	},
	{
		weight = 1,
		run = function()
			for _, chandelier in CollectionService:GetTagged("Chandelier") do
				if chandelier:IsDescendantOf(workspace) and math.random() < 0.5 then
					local pivot = chandelier:GetPivot()
					local value = Instance.new("CFrameValue")
					value.Value = pivot
					value.Changed:Connect(function(cf)
						chandelier:PivotTo(cf)
					end)
					local tween = TweenService:Create(value, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {
						Value = pivot * CFrame.Angles(math.rad(6), 0, math.rad(4)),
					})
					tween.Completed:Connect(function()
						value:Destroy()
					end)
					tween:Play()
					return true
				end
			end
			return false
		end,
	},
}

local function randomEvent()
	local entry = randomParticipant()
	if not entry or not Run.Flag("entered") then
		return
	end
	local total = 0
	for _, e in randomEvents do
		total += e.weight
	end
	for _ = 1, 4 do
		local r = math.random() * total
		for _, e in randomEvents do
			r -= e.weight
			if r <= 0 then
				local ok, result = pcall(e.run, entry)
				if ok and result then
					return
				end
				break
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Scripted sequences
----------------------------------------------------------------------------------------

function Events.EntranceSlam()
	local door = Doors.Get("FrontDoor")
	if not door then
		return
	end
	task.wait(1.2)
	Run.Cinematic(nil, "LookAt", { position = door.cf.Position + Vector3.new(0, 5, 0), duration = 2.4 })
	task.wait(0.6)
	Doors.SetOpen(door, false, nil, { slam = true })
	Doors.Lock(door, "انصفقت الأبواب خلفك. لن تُفتح مرة أخرى.")
	Run.Cinematic(nil, "Shake", { intensity = 0.6, duration = 0.6 })
	Power.Flicker(nil, nil, 1.2, "Ext")
	task.wait(1.5)
	Run.Cinematic(nil, "Subtitle", { text = "انصفقت الأبواب. لا طريق للعودة.", duration = 4 })
end

function Events.PowerOn(instant: boolean?)
	Run.Flags.power = true
	if instant then
		for _, zone in { "G", "F1", "F2", "F3", "Lift" } do
			Power.SetZone(zone, true)
		end
		return
	end
	Run.Cinematic(nil, "Shake", { intensity = 0.25, duration = 0.8 })
	Power.SetZone("G", true, true)
	task.wait(1.2)
	Power.SetZone("F1", true)
	Power.SetZone("F2", true)
	Power.SetZone("F3", true)
	Power.SetZone("Lift", true)
	Run.Cinematic(nil, "Subtitle", { text = "في مكان ما فوقك، يعود الفندق كله إلى الحياة بطنين خافت.", duration = 4 })
	-- the elevator opens by itself in the hall
	task.wait(7)
	if not Elevator.Busy then
		Sounds.Play("Ding", Elevator.Landings.G and Elevator.Landings.G.indicatorPart)
		Elevator.SetDoors("G", true)
		for _, entry in Run.Characters(false) do
			if (entry.root.Position - Vector3.new(0, 0, 30)).Magnitude < 45 then
				Run.Cinematic(entry.player, "LookAt", { position = Vector3.new(0, 5, 36), duration = 2 })
			end
		end
		Run.Notify(nil, "انفتحت أبواب المصعد... ولم يضغط أحد الزر.", "info")
	end
end

-- First arrival on the third floor: a shadow stands at the end of the corridor.
function Events.ShadowCorridor()
	local refs = hotelRefs()
	local Rig = require(Monsters.Rig)
	local apparition = Rig.Shadow()
	for _, d in apparition:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local far = refs.F3FarEnd
	apparition:PivotTo(CFrame.lookAt(far + Vector3.new(0, 4.6, 0), far + Vector3.new(10, 4.6, 0)))
	apparition.Parent = Run.Map and Run.Map:FindFirstChild("Monsters") or workspace
	local viewers = {}
	for _, entry in Run.Characters(true) do
		if entry.root.Position.Y > Config.Floors.F3 - 2 then
			table.insert(viewers, entry.player)
		end
	end
	task.wait(1.5)
	Run.Cinematic(viewers, "LookAt", { position = far + Vector3.new(0, 6, 0), duration = 3 })
	Sounds.Play("Growl", apparition:FindFirstChild("Head"))
	task.wait(2)
	-- lights die one by one toward the players
	Power.SetZone("F3", false, true)
	task.wait(1.2)
	apparition:Destroy()
	task.wait(2.5)
	Power.SetZone("F3", true, true)
	Run.Cinematic(viewers, "Subtitle", { text = "لقد رآك. أبقِ ضوءك منخفضًا... وخطواتك هادئة.", duration = 5 })
	task.wait(6)
	if monsters().ShadowMode() == "off" then
		monsters().SetShadowMode("upper")
	end
end

-- The Roomkeeper's face in the mirror of Room 307.
function Events.MirrorScare()
	local refs = hotelRefs()
	local glass, backing = refs.MirrorGlass, refs.MirrorBacking
	if not glass or not backing then
		return
	end
	local viewers = {}
	for _, entry in Run.Characters(true) do
		if (entry.root.Position - glass.Position).Magnitude < 30 then
			table.insert(viewers, entry.player)
		end
	end
	Run.Cinematic(viewers, "Focus", { cf = refs.MirrorViewCF, duration = 3.4 })
	task.wait(1.2)
	local Rig = require(Monsters.Rig)
	local figure = Rig.Roomkeeper()
	for _, d in figure:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	figure:PivotTo(refs.MirrorFigure + Vector3.new(0, 3.4, 0))
	figure.Parent = Run.Map and Run.Map:FindFirstChild("Monsters") or workspace
	backing.Transparency = 1
	backing.CanCollide = false
	local oldT = glass.Transparency
	glass.Transparency = 0.75
	Sounds.Play("Scream", glass)
	Run.Cinematic(viewers, "Scare", { color = Color3.fromRGB(255, 255, 255) })
	task.wait(0.9)
	figure:Destroy()
	backing.Transparency = 0
	backing.CanCollide = true
	glass.Transparency = oldT
	Power.Flicker(glass.Position, 30, 1.5)
	Run.Cinematic(viewers, "Subtitle", { text = "غرفة لينا. لا بد أن مذكراتها هنا في مكان ما.", duration = 4 })
end

-- Mission "Unlock the basement": the reception phone rings until somebody answers.
function Events.PhoneCall()
	local refs = hotelRefs()
	local phone = refs.ReceptionPhone
	if not phone or Events.PhoneBusy then
		return
	end
	Events.PhoneBusy = true
	local answered = false
	local prompt
	prompt = Interact.Add(phone, { text = "أجب", object = "هاتف الاستقبال", dist = 8, los = false }, function(player)
		if answered then
			return
		end
		answered = true
		prompt:Destroy()
		Run.Cinematic(player, "Focus", { cf = CFrame.lookAt(Vector3.new(0, 5.4, -4), Vector3.new(0, 5, 6.5)), duration = 9 })
		local m = monsters()
		if m.Concierge then
			m.Concierge:Show(refs.ConciergeDesk, 9, true)
		end
		local lines = {
			"«مساء الخير. فندق غراند أوريليا يشكرك على صبرك.»",
			"«المفتاح الذي تبحث عنه ينتظرك عند المكتب.»",
			"«انتبه للدرج. شيء ما يعيش هناك في الأسفل... وهو جائع جدًا.»",
		}
		for _, line in lines do
			Run.Cinematic(nil, "Subtitle", { text = line, duration = 3, voice = true })
			task.wait(3)
		end
		Pickups.Add(Run.Map, refs.DeskKeyCF, "BasementKey")
		Power.Flicker(nil, nil, 2.5, "G")
		Events.PhoneBusy = false
	end)
	task.spawn(function()
		local rings = 0
		while not answered and Run.IsPlaying() and phone.Parent do
			Sounds.Play("PhoneRing", phone)
			rings += 1
			if rings % 8 == 1 then
				Run.Notify(nil, "الهاتف في الاستقبال يرنّ...", "info")
			end
			task.wait(2.2)
		end
	end)
end

function Events.Room308Opens()
	Doors.Unlock("Room308")
	task.wait(0.8)
	Doors.SetOpen("Room308", true, nil, {})
	local door = Doors.Get("Room308")
	if door and door.anchor then
		Sounds.Play("Creak", door.anchor)
		Sounds.Play("Whisper", door.anchor)
	end
end

function Events.BasementDark(players)
	Run.Cinematic(players, "Subtitle", { text = "الظلام هنا يتنفّس. ابحث عن المولّد.", duration = 5 })
end

function Events.HeartReveal(players)
	local refs = hotelRefs()
	if refs.HeartCore then
		Run.Cinematic(players, "LookAt", { position = refs.HeartCore.Position, duration = 2.5 })
		Run.Cinematic(players, "Subtitle", { text = "قلب الفندق. ينبض وكأنه كائن حي.", duration = 5 })
	end
end

function Events.Reset()
	triggers = {}
	Events.PhoneBusy = false
end

----------------------------------------------------------------------------------------
-- Loops
----------------------------------------------------------------------------------------

function Events.Init()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(pollTriggers)
			if not ok then
				warn("[Events] trigger error:", err)
			end
		end
	end)
	-- randomized horror events
	task.spawn(function()
		while true do
			local rate = Run.Diff().eventRate
			task.wait(math.random(22, 48) / rate)
			if Run.IsPlaying() then
				randomEvent()
			end
		end
	end)
	-- lightning (synced for every client, lobby included)
	task.spawn(function()
		while true do
			task.wait(math.random(14, 38))
			Net.Event("Cinematic"):FireAllClients("Lightning", { seed = math.random(1, 1000) })
		end
	end)
	-- the Heart pulses; the facade sign sputters
	task.spawn(function()
		while true do
			task.wait(1.15)
			local refs = hotelRefs()
			local core = refs.HeartCore
			if core and core.Parent and not refs.HeartDead then
				local base = refs.HeartBase or core.Size
				refs.HeartBase = base
				TweenService:Create(core, TweenInfo.new(0.12), { Size = base * 1.12 }):Play()
				task.delay(0.15, function()
					TweenService:Create(core, TweenInfo.new(0.5), { Size = base }):Play()
				end)
				if refs.HeartLight then
					refs.HeartLight.Brightness = 3
					task.delay(0.2, function()
						refs.HeartLight.Brightness = 1.6
					end)
				end
				if #Players:GetPlayers() > 0 then
					Sounds.Play("Heart", core)
				end
			end
			local sign = refs.FacadeSign
			if sign and math.random() < 0.12 then
				sign.Text = ({ "غراند أو  ليا", "غرا د أوريليا", "غراند أوريليا", "   ند أوري  ا" })[math.random(1, 4)]
				task.delay(0.3, function()
					sign.Text = "غراند أوريليا"
				end)
			end
		end
	end)
end

return Events
