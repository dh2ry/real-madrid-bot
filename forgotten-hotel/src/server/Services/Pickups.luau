--!nonstrict
-- World pickups (keys, cards, batteries...) and readable documents.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Documents = require(Shared.Documents)
local Sounds = require(Shared.Sounds)
local Net = require(Shared.Net)

local Build = require(script.Parent.Parent.Map.Build)
local Run = require(script.Parent.Run)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)

local Pickups = {}
Pickups.Active = {} :: { [string]: { Model } }
Pickups.OnDocument = nil :: ((Player, string) -> ())?

local C = Config.Palette
local M = Enum.Material
local D, Cyl, Ball = Build.D, Build.Cyl, Build.Ball

local function keyModel(m: Model, cf: CFrame, color: Color3)
	Cyl(m, 0.55, 0.12, cf * CFrame.new(-0.5, 0.06, 0), color, M.Metal, { decor = true })
	D(m, Vector3.new(0.9, 0.1, 0.14), cf * CFrame.new(0.15, 0.06, 0), color, M.Metal)
	D(m, Vector3.new(0.12, 0.1, 0.3), cf * CFrame.new(0.45, 0.06, 0.15), color, M.Metal)
	D(m, Vector3.new(0.12, 0.1, 0.22), cf * CFrame.new(0.3, 0.06, 0.12), color, M.Metal)
	D(m, Vector3.new(0.5, 0.04, 0.32), cf * CFrame.new(-0.95, 0.03, 0.1), C.Burgundy, M.Fabric)
end

local Visuals = {
	ReceptionKey = function(m, cf)
		keyModel(m, cf, C.Gold)
	end,
	Key307 = function(m, cf)
		keyModel(m, cf, Color3.fromRGB(150, 130, 100))
	end,
	BasementKey = function(m, cf)
		keyModel(m, cf, Color3.fromRGB(90, 90, 96))
	end,
	ElevatorCard = function(m, cf)
		D(m, Vector3.new(0.9, 0.04, 0.6), cf * CFrame.new(0, 0.03, 0), C.Gold, M.Foil)
		D(m, Vector3.new(0.9, 0.05, 0.12), cf * CFrame.new(0, 0.04, -0.18), C.Black, M.SmoothPlastic)
	end,
	Fuse = function(m, cf)
		Cyl(m, 0.45, 1, cf * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Bone, M.SmoothPlastic, { decor = true })
		for _, x in { -0.55, 0.55 } do
			Cyl(m, 0.5, 0.15, cf * CFrame.new(x, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 120, 70), M.Metal, { decor = true })
		end
	end,
	FuelCan = function(m, cf)
		D(m, Vector3.new(1.2, 1.6, 0.7), cf * CFrame.new(0, 0.8, 0), Color3.fromRGB(150, 24, 20), M.Metal)
		D(m, Vector3.new(0.8, 0.2, 0.2), cf * CFrame.new(0, 1.75, 0), C.Charcoal, M.Metal)
		D(m, Vector3.new(0.2, 0.4, 0.2), cf * CFrame.new(0.4, 1.8, 0) * CFrame.Angles(0, 0, -0.4), Color3.fromRGB(150, 24, 20), M.Metal)
	end,
	Locket = function(m, cf)
		Ball(m, 0.35, (cf * CFrame.new(0, 0.18, 0)).Position, Color3.fromRGB(200, 205, 215), M.Metal, { decor = true })
		D(m, Vector3.new(0.9, 0.03, 0.05), cf * CFrame.new(0.5, 0.03, 0.1) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(200, 205, 215), M.Metal)
	end,
	Battery = function(m, cf)
		Cyl(m, 0.4, 0.9, cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 32), M.SmoothPlastic, { decor = true })
		Cyl(m, 0.42, 0.25, cf * CFrame.new(0.35, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 140, 60), M.Metal, { decor = true })
	end,
	Bandage = function(m, cf)
		D(m, Vector3.new(0.9, 0.35, 0.6), cf * CFrame.new(0, 0.18, 0), C.Bone, M.Fabric)
		D(m, Vector3.new(0.5, 0.37, 0.12), cf * CFrame.new(0, 0.18, 0), Color3.fromRGB(170, 20, 20), M.SmoothPlastic)
		D(m, Vector3.new(0.12, 0.37, 0.4), cf * CFrame.new(0, 0.18, 0), Color3.fromRGB(170, 20, 20), M.SmoothPlastic)
	end,
}

-- `cf` sits on the surface the item lies on.
function Pickups.Add(parent: Instance, cf: CFrame, itemId: string, opts)
	opts = opts or {}
	local def = Items[itemId]
	local m = Build.Model(parent, "Pickup_" .. itemId)
	m:SetAttribute("Item", itemId)
	local builder = Visuals[itemId]
	if builder then
		builder(m, cf)
	end
	local anchor = Interact.Anchor(m, (cf * CFrame.new(0, 0.4, 0)).Position, "Anchor")
	local glint = Instance.new("PointLight")
	glint.Range = 5
	glint.Brightness = 0.5
	glint.Color = Color3.fromRGB(255, 220, 160)
	glint.Shadows = false
	glint.Parent = anchor

	local list = Pickups.Active[itemId] or {}
	Pickups.Active[itemId] = list
	table.insert(list, m)

	Interact.Add(anchor, {
		text = "خذ",
		object = def.name,
		hold = opts.hold or 0.3,
		dist = opts.dist or 7,
	}, function(player)
		if not m.Parent then
			return
		end
		if not def.stack and Inventory.Has(player, itemId) then
			Run.Notify(player, "أنت تحمل " .. def.name .. " بالفعل.", "info")
			return
		end
		m:Destroy()
		local i = table.find(list, m)
		if i then
			table.remove(list, i)
		end
		Inventory.Add(player, itemId, opts.count or 1)
		Sounds.PlayAt("Pickup", anchor.Position)
		Run.Notify(player, "التقطت: " .. def.name, "item")
		if opts.onTaken then
			opts.onTaken(player)
		end
	end)
	return m
end

function Pickups.RemoveAll(itemId: string)
	for _, m in Pickups.Active[itemId] or {} do
		m:Destroy()
	end
	Pickups.Active[itemId] = {}
end

-- Drops a disconnected player's critical items where they stood.
function Pickups.DropCritical(player: Player, position: Vector3)
	local map = Run.Map
	if not map then
		return
	end
	local offset = 0
	for id, count in Inventory.Snapshot(player) do
		local teammateHas = false
		for other, data in Inventory.Data do
			if other ~= player and other.Parent and (data[id] or 0) > 0 then
				teammateHas = true
			end
		end
		if Items[id] and Items[id].critical and count > 0 and not teammateHas then
			-- only drop if no teammate already carries the same key
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character }
			local origin = position + Vector3.new(offset, 2, 0)
			local hit = workspace:Raycast(origin, Vector3.new(0, -20, 0), params)
			local ground = hit and hit.Position or (position - Vector3.new(0, 3, 0))
			Pickups.Add(map, CFrame.new(ground), id)
			offset += 1.2
		end
	end
end

----------------------------------------------------------------------------------------
-- Documents
----------------------------------------------------------------------------------------

function Pickups.Document(parent: Instance, cf: CFrame, docId: string)
	local doc = Documents[docId]
	assert(doc, "unknown document " .. docId)
	local m = Build.Model(parent, "Document_" .. docId)
	if doc.journal then
		D(m, Vector3.new(1.4, 0.35, 1.9), cf * CFrame.new(0, 0.18, 0), Color3.fromRGB(60, 22, 24), M.Leather)
		D(m, Vector3.new(1.3, 0.3, 1.8), cf * CFrame.new(0.06, 0.18, 0), C.Paper, M.SmoothPlastic)
		D(m, Vector3.new(0.3, 0.37, 1.92), cf * CFrame.new(-0.55, 0.18, 0), C.Gold, M.Metal)
	else
		D(m, Vector3.new(1.1, 0.04, 1.5), cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(8), 0), C.Paper, M.SmoothPlastic)
		D(m, Vector3.new(0.8, 0.045, 0.06), cf * CFrame.new(0, 0.05, -0.4) * CFrame.Angles(0, math.rad(8), 0), Color3.fromRGB(60, 50, 40), M.SmoothPlastic)
	end
	local anchor = Interact.Anchor(m, (cf * CFrame.new(0, 0.4, 0)).Position, "Anchor")
	local glint = Instance.new("PointLight")
	glint.Range = 4
	glint.Brightness = 0.35
	glint.Color = Color3.fromRGB(255, 236, 200)
	glint.Shadows = false
	glint.Parent = anchor
	Interact.Add(anchor, {
		text = "اقرأ",
		object = doc.title,
		dist = 7,
	}, function(player)
		Sounds.PlayAt("Paper", anchor.Position)
		Net.Event("Document"):FireClient(player, docId)
		local isNew = not Run.Docs[docId]
		if isNew then
			Run.Docs[docId] = true
			Run.Notify(nil, string.format("وُجدت وثيقة: %s (%d/%d)", doc.title, Run.DocCount(), Config.TotalDocuments), "doc")
			Run.DocFound:Fire(docId, player)
		end
		if Pickups.OnDocument then
			Pickups.OnDocument(player, docId)
		end
		glint.Enabled = false
	end)
	return m
end

function Pickups.Reset()
	Pickups.Active = {}
end

return Pickups
