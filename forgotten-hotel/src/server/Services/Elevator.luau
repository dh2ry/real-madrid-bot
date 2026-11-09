--!nonstrict
-- The main elevator. The car is moved between floors while its doors are shut and the
-- riders are carried with it (offset preserved), which is robust for any player count and
-- never desyncs physics. Needs power + the access card (inserted once for the whole team).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Signal = require(Shared.Signal)

local Build = require(script.Parent.Parent.Map.Build)
local Run = require(script.Parent.Run)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)

local Elevator = {}
Elevator.Current = "G"
Elevator.Busy = false
Elevator.Arrived = Signal.new() -- (floor, riders)
Elevator.Landings = {} :: { [string]: any }
Elevator.Car = nil :: Model?

local C = Config.Palette
local M = Enum.Material
local SHAFT = { x1 = -5, x2 = 5, z1 = 36, z2 = 46 }
local DOOR_Z = 35.75

local function floorY(floor: string): number
	return Config.Floors[floor]
end

local function setLandingDoors(floor: string, open: boolean, instant: boolean?)
	local landing = Elevator.Landings[floor]
	if not landing then
		return
	end
	landing.open = open
	for i, leaf in landing.leaves do
		local closedX = i == 1 and -1.5 or 1.5
		local openX = i == 1 and -4.3 or 4.3
		local target = CFrame.new(open and openX or closedX, floorY(floor) + 4.5, DOOR_Z)
		if instant then
			leaf.CFrame = target
		else
			TweenService:Create(leaf, TweenInfo.new(1, Enum.EasingStyle.Sine), { CFrame = target }):Play()
		end
	end
end
Elevator.SetDoors = setLandingDoors

local function updateIndicators(text: string)
	for _, landing in Elevator.Landings do
		landing.indicator.Text = text
	end
	if Elevator.CarIndicator then
		Elevator.CarIndicator.Text = text
	end
end

local function riders(): { { player: Player, character: Model } }
	local y = floorY(Elevator.Current)
	local list = {}
	for _, entry in Run.Characters(true) do
		local p = entry.root.Position
		if p.X > SHAFT.x1 - 0.2 and p.X < SHAFT.x2 + 0.2 and p.Z > DOOR_Z + 0.1 and p.Z < SHAFT.z2 and p.Y > y - 1 and p.Y < y + 12 then
			table.insert(list, { player = entry.player, character = entry.character })
		end
	end
	return list
end

function Elevator.Travel(target: string, ghost: boolean?)
	if Elevator.Busy or not Elevator.Car then
		return
	end
	if target == Elevator.Current then
		setLandingDoors(target, true)
		return
	end
	Elevator.Busy = true
	local from = Elevator.Current
	setLandingDoors(from, false)
	task.wait(1.2)
	local carried = riders()
	local delta = Vector3.new(0, floorY(target) - floorY(from), 0)
	local floors = math.abs(table.find(Config.ElevatorFloors, target) - table.find(Config.ElevatorFloors, from))
	local duration = math.max(2.6, floors * 1.4)
	local players = {}
	for _, r in carried do
		table.insert(players, r.player)
	end
	if #players > 0 then
		Run.Cinematic(players, "ElevatorRide", { duration = duration })
	end
	Elevator.Car:PivotTo(Elevator.Car:GetPivot() + delta)
	for _, r in carried do
		r.character:PivotTo(r.character:GetPivot() + delta)
	end
	local hum = Sounds.Make("ElevatorRun", Elevator.Car.PrimaryPart)
	if hum then
		hum:Play()
	end
	updateIndicators("...")
	task.wait(duration)
	if hum then
		hum:Destroy()
	end
	Elevator.Current = target
	updateIndicators(Config.ElevatorLabels[target])
	Sounds.Play("Ding", Elevator.Landings[target].indicatorPart)
	setLandingDoors(target, true)
	Elevator.Busy = false
	Elevator.Arrived:Fire(target, players, ghost == true)
end

function Elevator.Request(floor: string, player: Player?)
	if not Run.Flag("power") then
		if player then
			Run.Notify(player, "لا شيء يحدث. المصعد بلا كهرباء.", "warn")
		end
		return
	end
	if not Run.Flag("elevator") then
		if player then
			Run.Notify(player, "اللوحة تومض: مطلوب بطاقة دخول الموظفين.", "warn")
		end
		return
	end
	if Elevator.Busy then
		if player then
			Run.Notify(player, "المصعد يتحرك...", "info")
		end
		return
	end
	task.spawn(Elevator.Travel, floor)
end

local function buildLanding(parent: Instance, floor: string)
	local y = floorY(floor)
	local wallStyle = { color = C.Marble, material = M.Marble, thickness = 0.8 }
	Build.Wall(parent, SHAFT.x1, SHAFT.z1, SHAFT.x1, SHAFT.z2, y, 15, wallStyle)
	Build.Wall(parent, SHAFT.x2, SHAFT.z1, SHAFT.x2, SHAFT.z2, y, 15, wallStyle)
	Build.Wall(parent, SHAFT.x1, SHAFT.z2, SHAFT.x2, SHAFT.z2, y, 15, wallStyle)
	Build.Wall(parent, SHAFT.x1 - 0.4, SHAFT.z1, SHAFT.x2 + 0.4, SHAFT.z1, y, 15, { color = C.Gold, material = M.Metal, thickness = 0.9 }, {
		{ c = 0, w = 6, h = 9 },
	})
	-- decorative surround
	Build.D(parent, Vector3.new(7.4, 0.6, 0.4), CFrame.new(0, y + 9.3, DOOR_Z - 0.5), C.DimGold, M.Metal)
	for _, x in { -3.4, 3.4 } do
		Build.D(parent, Vector3.new(0.6, 9, 0.4), CFrame.new(x, y + 4.5, DOOR_Z - 0.5), C.DimGold, M.Metal)
	end
	local leaves = {}
	for i = 1, 2 do
		local leaf = Build.P(parent, Vector3.new(3.05, 9, 0.3), CFrame.new(i == 1 and -1.5 or 1.5, y + 4.5, DOOR_Z), C.Gold, M.Metal, { name = "LiftDoor" })
		leaf.Reflectance = 0.1
		table.insert(leaves, leaf)
	end
	local indicatorPart, indicator = Build.Text(parent, Vector3.new(1.6, 1.2, 0.1), Build.At(0, y + 10.6, DOOR_Z - 0.55, "S"), Config.ElevatorLabels[Elevator.Current], {
		bg = Color3.fromRGB(20, 10, 8),
		color = Color3.fromRGB(255, 120, 60),
		font = Enum.Font.Arcade,
		brightness = 2,
		lightInfluence = 0,
	})
	local button = Build.D(parent, Vector3.new(0.6, 1, 0.2), CFrame.new(4.3, y + 4.5, DOOR_Z - 0.6), C.Gold, M.Metal, { name = "CallButton" })
	Build.Ball(parent, 0.3, button.Position + Vector3.new(0, 0, -0.15), Color3.fromRGB(255, 150, 80), M.Neon, { decor = true })
	Interact.Add(button, { text = "استدعِ", object = "المصعد", dist = 7 }, function(player)
		Sounds.Play("Click", button)
		Elevator.Request(floor, player)
	end)
	Elevator.Landings[floor] = { leaves = leaves, indicator = indicator, indicatorPart = indicatorPart, open = false }
end

local function buildCar(parent: Instance)
	local y = floorY("G")
	local car = Build.Model(parent, "ElevatorCar")
	local root = Build.P(car, Vector3.new(1, 1, 1), CFrame.new(0, y, 41), Color3.new(), M.SmoothPlastic, { transparency = 1, decor = true, name = "CarRoot" })
	car.PrimaryPart = root
	Build.P(car, Vector3.new(9.2, 0.3, 9.4), CFrame.new(0, y + 0.15, 41), C.DeepBurgundy, M.Carpet)
	Build.D(car, Vector3.new(9.4, 0.1, 9.6), CFrame.new(0, y + 0.31, 41), C.Gold, M.Metal, { transparency = 0.9 })
	-- walls
	Build.P(car, Vector3.new(9.2, 10, 0.3), CFrame.new(0, y + 5, 45.65), C.Walnut, M.Wood)
	for _, x in { -4.65, 4.65 } do
		Build.P(car, Vector3.new(0.3, 10, 9.6), CFrame.new(x, y + 5, 41), C.Walnut, M.Wood)
		Build.D(car, Vector3.new(0.3, 0.3, 9.2), CFrame.new(x * 0.96, y + 3.4, 41), C.Gold, M.Metal)
	end
	Build.D(car, Vector3.new(9.2, 0.4, 9.6), CFrame.new(0, y + 10, 41), C.Charcoal, M.Metal)
	local _, mirrorGlass = nil, nil
	do
		local m = require(script.Parent.Parent.Map.Props)
		_, mirrorGlass = m.Mirror(car, Build.At(0, y + 5.5, 45.5, "S"), 5, 5, { broken = true, seed = 4 })
	end
	local lamp = Build.D(car, Vector3.new(3, 0.2, 3), CFrame.new(0, y + 9.75, 41), C.Bone, M.Neon, { name = "Bulb" })
	Build.Light(lamp, "PointLight", { Range = 14, Brightness = 1.2, Color = C.Warm, Shadows = false }, "Lift")
	-- control panel on the right wall (facing into the car)
	local panelCF = Build.At(4.45, y + 4.5, 38.5, "W")
	Build.D(car, Vector3.new(1.4, 3.2, 0.15), panelCF * CFrame.new(0, 0, -0.05), C.Gold, M.Metal)
	for i, floor in Config.ElevatorFloors do
		Build.Text(car, Vector3.new(0.5, 0.5, 0.05), panelCF * CFrame.new(0, -1.1 + (i - 1) * 0.65, -0.14), Config.ElevatorLabels[floor], {
			bg = Color3.fromRGB(240, 220, 170),
			color = C.Black,
			font = Enum.Font.Bodoni,
		})
	end
	local _, carIndicator = Build.Text(car, Vector3.new(1.2, 0.6, 0.05), panelCF * CFrame.new(0, 1.3, -0.14), "G", {
		bg = Color3.fromRGB(20, 10, 8),
		color = Color3.fromRGB(255, 120, 60),
		font = Enum.Font.Arcade,
		brightness = 2,
		lightInfluence = 0,
	})
	Elevator.CarIndicator = carIndicator
	local panelAnchor = Interact.Anchor(car, (panelCF * CFrame.new(0, 0, -0.8)).Position, "PanelAnchor")
	Interact.Add(panelAnchor, { text = "اختر الطابق", object = "لوحة المصعد", dist = 6, los = false }, function(player)
		if not Run.Flag("elevator") then
			if Inventory.Has(player, "ElevatorCard") then
				Run.SetFlag("elevator", true)
				Sounds.Play("Unlock", panelAnchor)
				Run.Notify(nil, player.DisplayName .. " أدخل بطاقة الدخول. استيقظ المصعد بطنين خافت.", "item")
			else
				Run.Notify(player, "مطلوب بطاقة دخول الموظفين.", "warn")
				Sounds.Play("Locked", panelAnchor)
				return
			end
		end
		if not Run.Flag("power") then
			Run.Notify(player, "اللوحة مظلمة. لا كهرباء.", "warn")
			return
		end
		Net.Event("Choice"):FireClient(player, "elevator", {
			current = Elevator.Current,
			floors = Config.ElevatorFloors,
			labels = Config.ElevatorLabels,
			names = Config.FloorNames,
		})
	end)
	Elevator.Car = car
	Elevator.MirrorGlass = mirrorGlass
	return car
end

function Elevator.Build(parent: Instance)
	Elevator.Current = "G"
	Elevator.Busy = false
	Elevator.Landings = {}
	local folder = Build.Folder(parent, "Elevator")
	for _, floor in Config.ElevatorFloors do
		buildLanding(folder, floor)
	end
	buildCar(folder)
	for _, floor in Config.ElevatorFloors do
		setLandingDoors(floor, false, true)
	end
end

-- The elevator moves by itself (random horror event).
function Elevator.Ghost(): boolean
	if Elevator.Busy or not Run.Flag("power") or #riders() > 0 then
		return false
	end
	local options = {}
	for _, floor in Config.ElevatorFloors do
		if floor ~= Elevator.Current then
			table.insert(options, floor)
		end
	end
	task.spawn(Elevator.Travel, options[math.random(1, #options)], true)
	return true
end

function Elevator.Init()
	Net.Event("Choice").OnServerEvent:Connect(function(player, context, choice)
		if context ~= "elevator" or typeof(choice) ~= "string" then
			return
		end
		if not Net.Allow(player, "elevator", 0.5) or not table.find(Config.ElevatorFloors, choice) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local car = Elevator.Car
		if not root or not car then
			return
		end
		if (root.Position - car:GetPivot().Position).Magnitude > 9 then
			return
		end
		Elevator.Request(choice, player)
	end)
end

return Elevator
