--!nonstrict
-- Hiding in wardrobes, lockers and under beds. While hidden the character is anchored
-- inside the spot and made invisible; monsters ignore hidden players unless they SAW the
-- player hide (within a short window), in which case they drag them out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Signal = require(Shared.Signal)

local Run = require(script.Parent.Run)
local Interact = require(script.Parent.Interact)

local Hiding = {}
Hiding.Spots = {} :: { any }
Hiding.Entered = Signal.new() -- (player, spot)
Hiding.Exited = Signal.new() -- (player, spot, forced)

local occupant: { [any]: Player } = {}
local spotOf: { [Player]: any } = {}
local hiddenAt: { [Player]: number } = {}

local function swingDoors(spot, open: boolean)
	for _, name in { "DoorL", "DoorR" } do
		local door = spot.model:FindFirstChild(name)
		if door then
			local closed = door:GetAttribute("ClosedCF")
			local sign = name == "DoorL" and 1 or -1
			local hingeX = (name == "DoorL" and -door.Size.X / 2 or door.Size.X / 2)
			local target = closed
			if open then
				target = closed * CFrame.new(hingeX, 0, 0) * CFrame.Angles(0, sign * math.rad(70), 0) * CFrame.new(-hingeX, 0, 0)
			end
			TweenService:Create(door, TweenInfo.new(0.25), { CFrame = target }):Play()
			-- decorative children follow (panel + knob)
			for _, d in spot.model:GetChildren() do
				if d:GetAttribute("Door") == name and d:IsA("BasePart") then
					local rel = d:GetAttribute("Rel")
					if not rel then
						rel = closed:ToObjectSpace(d.CFrame)
						d:SetAttribute("Rel", rel)
					end
					TweenService:Create(d, TweenInfo.new(0.25), { CFrame = target * rel }):Play()
				end
			end
		end
	end
end

local function setVisible(character: Model, visible: boolean)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if visible then
				local original = d:GetAttribute("HideOriginalT")
				if original ~= nil then
					d.Transparency = original
					d:SetAttribute("HideOriginalT", nil)
				end
			else
				if d:GetAttribute("HideOriginalT") == nil then
					d:SetAttribute("HideOriginalT", d.Transparency)
				end
				d.Transparency = 1
			end
		elseif d:IsA("Decal") then
			d.Transparency = visible and 0 or 1
		end
	end
end

function Hiding.Enter(player: Player, spot)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root or occupant[spot] or spotOf[player] then
		return
	end
	occupant[spot] = player
	spotOf[player] = spot
	hiddenAt[player] = os.clock()
	root.Anchored = true
	character:PivotTo(spot.hide.CFrame)
	character:SetAttribute("Hidden", true)
	character:SetAttribute("HiddenSince", workspace:GetServerTimeNow())
	setVisible(character, false)
	if spot.kind == "wardrobe" then
		swingDoors(spot, true)
		task.delay(0.35, function()
			swingDoors(spot, false)
		end)
		Sounds.Play("Creak", spot.hide)
	else
		Sounds.Play("Footstep", spot.hide)
	end
	spot.prompt.ActionText = "اخرج"
	Net.Event("Cinematic"):FireClient(player, "HideView", { cf = spot.view.CFrame, kind = spot.kind })
	Hiding.Entered:Fire(player, spot)
end

function Hiding.Exit(player: Player, forced: boolean?)
	local spot = spotOf[player]
	if not spot then
		return
	end
	occupant[spot] = nil
	spotOf[player] = nil
	hiddenAt[player] = nil
	spot.prompt.ActionText = "اختبئ"
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		character:SetAttribute("Hidden", false)
		setVisible(character, true)
		character:PivotTo(spot.exit.CFrame)
		if root then
			root.Anchored = false
		end
	end
	if spot.kind == "wardrobe" then
		swingDoors(spot, true)
		task.delay(0.6, function()
			swingDoors(spot, false)
		end)
		Sounds.Play(forced and "DoorSlam" or "Creak", spot.hide)
	end
	Net.Event("Cinematic"):FireClient(player, "Unhide", { forced = forced })
	Hiding.Exited:Fire(player, spot, forced)
end

function Hiding.IsHidden(player: Player): boolean
	return spotOf[player] ~= nil
end

function Hiding.SpotOf(player: Player)
	return spotOf[player]
end

-- Seconds since the player hid (nil if not hidden).
function Hiding.HiddenFor(player: Player): number?
	local t = hiddenAt[player]
	return t and os.clock() - t or nil
end

function Hiding.Add(model: Model)
	local hide = model:FindFirstChild("HideSpot")
	local exit = model:FindFirstChild("ExitPoint")
	local view = model:FindFirstChild("ViewPoint")
	if not hide or not exit or not view then
		warn("[Hiding] model missing hide markers", model:GetFullName())
		return
	end
	local kind = model:GetAttribute("HideKind") or "wardrobe"
	local spot = { model = model, hide = hide, exit = exit, view = view, kind = kind }
	-- prompt sits in front of the furniture
	local anchor = Interact.Anchor(model, exit.Position + Vector3.new(0, kind == "bed" and -1.5 or 1, 0) + (hide.Position - exit.Position) * 0.45, "HidePrompt")
	spot.prompt = Interact.Add(anchor, {
		text = "اختبئ",
		object = kind == "bed" and "تحت السرير" or (model.Name == "Locker" and "خزانة معدنية" or "خزانة ملابس"),
		dist = 7,
		los = false,
		allowHidden = true,
		hold = 0,
	}, function(player)
		if spotOf[player] == spot then
			Hiding.Exit(player, false)
		elseif not spotOf[player] then
			if occupant[spot] then
				Run.Notify(player, "هناك من يختبئ هنا بالفعل.", "info")
				return
			end
			Hiding.Enter(player, spot)
		end
	end)
	table.insert(Hiding.Spots, spot)
	return spot
end

function Hiding.Init()
	Net.Event("Hide").OnServerEvent:Connect(function(player)
		if Net.Allow(player, "hide", 0.4) then
			Hiding.Exit(player, false)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local spot = spotOf[player]
		if spot then
			occupant[spot] = nil
			spotOf[player] = nil
		end
	end)
end

-- Called when a character dies/respawns so stale state never blocks a spot.
function Hiding.Clear(player: Player)
	local spot = spotOf[player]
	if spot then
		occupant[spot] = nil
		spotOf[player] = nil
		spot.prompt.ActionText = "اختبئ"
	end
	hiddenAt[player] = nil
end

function Hiding.Reset()
	Hiding.Spots = {}
	occupant = {}
	spotOf = {}
	hiddenAt = {}
end

return Hiding
