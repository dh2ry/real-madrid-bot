--!nonstrict
-- Hinged doors: locks, keys, barricades, slams. Door leaves belong to the "Doors"
-- collision group so monsters phase through them (and pathfinding treats them as open).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Sounds = require(Shared.Sounds)
local Signal = require(Shared.Signal)

local Build = require(script.Parent.Parent.Map.Build)
local Run = require(script.Parent.Run)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)

local Doors = {}
Doors.Registry = {} :: { [string]: any }
Doors.Changed = Signal.new() -- (id, isOpen, player?)
Doors.Unlocked = Signal.new() -- (id, player?)

local C = Config.Palette
local M = Enum.Material

local STYLES = {
	wood = { color = C.Walnut, material = M.Wood, panel = C.DarkBrown, frame = C.DarkBrown, knob = C.Gold },
	room = { color = Color3.fromRGB(70, 30, 30), material = M.Wood, panel = C.DeepBurgundy, frame = C.DimGold, knob = C.Gold },
	grand = { color = C.DarkBrown, material = M.Wood, panel = C.DarkBrown, frame = C.Gold, knob = C.Gold, glass = true },
	rotten = { color = Color3.fromRGB(70, 62, 56), material = M.WoodPlanks, panel = Color3.fromRGB(56, 50, 46), frame = Color3.fromRGB(60, 56, 52), knob = Color3.fromRGB(120, 110, 90) },
	metal = { color = Color3.fromRGB(70, 74, 76), material = M.DiamondPlate, panel = Color3.fromRGB(60, 62, 64), frame = Color3.fromRGB(40, 40, 42), knob = Color3.fromRGB(150, 150, 150) },
	steel = { color = Color3.fromRGB(60, 58, 56), material = M.CorrodedMetal, panel = Color3.fromRGB(80, 50, 36), frame = C.Charcoal, knob = Color3.fromRGB(150, 150, 150) },
	lab = { color = Color3.fromRGB(150, 155, 160), material = M.Metal, panel = Color3.fromRGB(120, 125, 130), frame = C.Charcoal, knob = Color3.fromRGB(40, 40, 40) },
}

local function promptText(door)
	if door.barricaded then
		return "ادفع"
	elseif door.locked then
		return "جرّب"
	elseif door.isOpen then
		return "أغلق"
	end
	return "افتح"
end

local function refresh(door)
	if door.prompt then
		door.prompt.ActionText = promptText(door)
		door.prompt.ObjectText = door.label or ""
	end
end

local function buildLeaf(door, parent, hingeCF: CFrame, width: number, height: number, side: number, style)
	-- side = 1: hinge on the left, leaf extends to +X. side = -1: hinge on the right.
	local leaf = Instance.new("Model")
	leaf.Name = "Leaf"
	local hinge = Build.P(leaf, Vector3.new(0.2, 0.2, 0.2), hingeCF, Color3.new(), M.SmoothPlastic, { transparency = 1, decor = true, name = "Hinge" })
	leaf.PrimaryPart = hinge
	local centre = hingeCF * CFrame.new(side * width / 2, height / 2, 0)
	local main = Build.P(leaf, Vector3.new(width, height, 0.35), centre, style.color, style.material, { name = "Panel" })
	main.CollisionGroup = "Doors"
	local modifier = Instance.new("PathfindingModifier")
	modifier.Label = "Door"
	modifier.PassThrough = true
	modifier.Parent = main
	if style.glass then
		Build.D(leaf, Vector3.new(width - 1, height * 0.45, 0.4), centre * CFrame.new(0, height * 0.15, 0), Color3.fromRGB(70, 90, 110), M.Glass, { transparency = 0.5 })
		Build.D(leaf, Vector3.new(width - 0.6, 0.25, 0.42), centre * CFrame.new(0, -height * 0.1, 0), C.Gold, M.Metal)
	else
		for _, face in { -1, 1 } do
			Build.D(leaf, Vector3.new(width - 1, height * 0.35, 0.1), centre * CFrame.new(0, height * 0.2, face * 0.2), style.panel, style.material)
			Build.D(leaf, Vector3.new(width - 1, height * 0.3, 0.1), centre * CFrame.new(0, -height * 0.22, face * 0.2), style.panel, style.material)
		end
	end
	for _, face in { -1, 1 } do
		Build.Ball(leaf, 0.35, (centre * CFrame.new(side * (width / 2 - 0.45), -0.4, face * 0.3)).Position, style.knob, M.Metal, { decor = true })
	end
	if door.number and side == 1 then
		Build.Text(leaf, Vector3.new(1.4, 0.7, 0.05), centre * CFrame.new(0, height * 0.42 - 0.6, -0.2), door.number, {
			bg = C.Gold,
			color = C.Black,
			font = Enum.Font.Bodoni,
			material = M.Metal,
		})
	end
	leaf.Parent = parent
	return { model = leaf, hingeCF = hingeCF, side = side }
end

-- opts: id, cf, w, h, style, locked, key, lockedText, double, number, label, open, barricaded, noPrompt, swing
function Doors.Add(parent: Instance, opts)
	local style = STYLES[opts.style or "wood"] or STYLES.wood
	local w, h = opts.w or 4.5, opts.h or 9
	local model = Build.Model(parent, "Door_" .. (opts.id or "anon"))
	local cf: CFrame = opts.cf
	local door = {
		id = opts.id,
		cf = cf,
		w = w,
		h = h,
		model = model,
		locked = opts.locked == true,
		key = opts.key,
		lockedText = opts.lockedText,
		barricaded = opts.barricaded == true,
		label = opts.label or (opts.number and ("الغرفة " .. opts.number)) or "باب",
		number = opts.number,
		isOpen = false,
		leaves = {},
		swing = opts.swing or 100,
		busy = false,
	}
	-- frame
	Build.D(model, Vector3.new(0.35, h + 0.3, 1.2), cf * CFrame.new(-w / 2 + 0.17, h / 2, 0), style.frame, M.Wood)
	Build.D(model, Vector3.new(0.35, h + 0.3, 1.2), cf * CFrame.new(w / 2 - 0.17, h / 2, 0), style.frame, M.Wood)
	Build.D(model, Vector3.new(w, 0.4, 1.2), cf * CFrame.new(0, h + 0.05, 0), style.frame, M.Wood)
	local clear = w - 0.4
	if opts.double then
		local half = clear / 2
		table.insert(door.leaves, buildLeaf(door, model, cf * CFrame.new(-clear / 2, 0, 0), half, h - 0.1, 1, style))
		table.insert(door.leaves, buildLeaf(door, model, cf * CFrame.new(clear / 2, 0, 0), half, h - 0.1, -1, style))
	else
		table.insert(door.leaves, buildLeaf(door, model, cf * CFrame.new(-clear / 2, 0, 0), clear, h - 0.1, 1, style))
	end
	if door.barricaded then
		local planks = Build.Model(model, "Barricade")
		for i, y in { 2.2, 4.4, 6.6 } do
			Build.P(planks, Vector3.new(w + 0.6, 0.6, 0.25), cf * CFrame.new(0, y, 0.6) * CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 8 or -8)), Color3.fromRGB(90, 70, 50), M.WoodPlanks)
		end
		door.barricade = planks
	end
	if not opts.noPrompt then
		local anchor = Interact.Anchor(model, (cf * CFrame.new(0, 4.5, 0)).Position, "PromptAnchor")
		door.anchor = anchor
		door.prompt = Interact.Add(anchor, {
			text = promptText(door),
			object = door.label,
			dist = 9,
			los = false,
		}, function(player)
			Doors.Use(door.id, player)
		end)
	end
	if door.id then
		Doors.Registry[door.id] = door
	end
	if opts.open then
		Doors.SetOpen(door, true, nil, { silent = true, instant = true })
	end
	return door
end

local function resolve(idOrDoor)
	if typeof(idOrDoor) == "string" then
		return Doors.Registry[idOrDoor]
	end
	return idOrDoor
end

function Doors.Get(id: string)
	return Doors.Registry[id]
end

function Doors.SetOpen(idOrDoor, open: boolean, player: Player?, opts)
	local door = resolve(idOrDoor)
	if not door or door.isOpen == open then
		return
	end
	opts = opts or {}
	door.isOpen = open
	local duration = opts.instant and 0 or (opts.slam and 0.18 or 0.7)
	for _, leaf in door.leaves do
		local target = open and math.rad(-leaf.side * door.swing) or 0
		-- cancel a swing that is still in progress and continue from where it is
		local current = leaf.current or 0
		if leaf.tween then
			leaf.tween:Cancel()
			leaf.tween = nil
		end
		if leaf.value then
			current = leaf.value.Value
			leaf.value:Destroy()
			leaf.value = nil
		end
		local value = Instance.new("NumberValue")
		value.Value = current
		local function apply()
			leaf.current = value.Value
			if leaf.model.Parent then
				leaf.model:PivotTo(leaf.hingeCF * CFrame.Angles(0, value.Value, 0))
			end
		end
		if duration <= 0 then
			value.Value = target
			apply()
			value:Destroy()
		else
			leaf.value = value
			value.Changed:Connect(apply)
			local tween = TweenService:Create(value, TweenInfo.new(duration, opts.slam and Enum.EasingStyle.Quad or Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = target })
			leaf.tween = tween
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and leaf.value == value then
					leaf.value = nil
					leaf.tween = nil
					value:Destroy()
				end
			end)
			tween:Play()
		end
	end
	if not opts.silent and door.anchor then
		local name = opts.slam and "DoorSlam" or (open and "DoorOpen" or "DoorClose")
		Sounds.Play(name, door.anchor)
	end
	refresh(door)
	Doors.Changed:Fire(door.id, open, player)
end

function Doors.Unlock(idOrDoor, player: Player?)
	local door = resolve(idOrDoor)
	if not door or not door.locked then
		return
	end
	door.locked = false
	refresh(door)
	if door.anchor then
		Sounds.Play("Unlock", door.anchor)
	end
	Doors.Unlocked:Fire(door.id, player)
end

function Doors.Lock(idOrDoor, text: string?)
	local door = resolve(idOrDoor)
	if not door then
		return
	end
	door.locked = true
	if text then
		door.lockedText = text
	end
	refresh(door)
end

function Doors.RemoveBarricade(idOrDoor)
	local door = resolve(idOrDoor)
	if not door or not door.barricaded then
		return
	end
	door.barricaded = false
	if door.barricade then
		for _, plank in door.barricade:GetChildren() do
			if plank:IsA("BasePart") then
				plank.Anchored = false
				plank.CanCollide = true
				plank.CollisionGroup = "Debris"
			end
		end
		task.delay(8, function()
			if door.barricade then
				door.barricade:Destroy()
			end
		end)
	end
	if door.anchor then
		Sounds.Play("Crash", door.anchor)
	end
	refresh(door)
end

function Doors.Use(id: string, player: Player)
	local door = Doors.Registry[id]
	if not door then
		return
	end
	if door.barricaded then
		Run.Notify(player, "إنه مسمّر من الجهة الأخرى.", "warn")
		Sounds.Play("Locked", door.anchor)
		return
	end
	if door.locked then
		if door.key and Inventory.Has(player, door.key) then
			Doors.Unlock(door, player)
			Run.Notify(player, "فُتح القفل باستخدام: " .. Items[door.key].name .. ".", "item")
		else
			Run.Notify(player, door.lockedText or "إنه مقفل.", "warn")
			Sounds.Play("Locked", door.anchor)
			return
		end
	end
	Doors.SetOpen(door, not door.isOpen, player)
end

function Doors.Slam(id: string)
	local door = Doors.Registry[id]
	if door then
		Doors.SetOpen(door, false, nil, { slam = true })
	end
end

function Doors.Reset()
	Doors.Registry = {}
end

return Doors
