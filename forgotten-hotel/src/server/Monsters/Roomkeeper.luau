--!nonstrict
-- THE ROOMKEEPER: guards specific rooms (Suite 203's bedroom, Room 307's nursery and
-- the ballroom stage). Entering one makes her appear and whisper a warning; stay past
-- the warning and she closes in with jerky, unnatural "skips" and attacks. She never
-- leaves her room, so stepping out is always the answer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)

local Services = script.Parent.Parent.Services
local Run = require(Services.Run)
local Power = require(Services.Power)
local Survival = require(Services.Survival)

local Rig = require(script.Parent.Rig)

local Roomkeeper = {}
Roomkeeper.__index = Roomkeeper

local cfg = Config.Roomkeeper
local ROOT_HEIGHT = 3.4

function Roomkeeper.new()
	local self = setmetatable({}, Roomkeeper)
	local model, root, head = Rig.Roomkeeper()
	self.model = model
	self.root = root
	self.head = head
	root.Anchored = true
	self.zone = nil
	self.state = "Idle"
	self.warnUntil = 0
	self.nextStep = 0
	self.cooldowns = {}
	return self
end

local function inside(zone, pos: Vector3): boolean
	return pos.X > zone.min.X and pos.X < zone.max.X and pos.Z > zone.min.Z and pos.Z < zone.max.Z and pos.Y > zone.min.Y and pos.Y < zone.max.Y
end

local function occupants(zone)
	local list = {}
	for _, entry in Run.Characters(false) do
		if not entry.character:GetAttribute("Hidden") and inside(zone, entry.root.Position) then
			table.insert(list, entry)
		end
	end
	return list
end

function Roomkeeper:Appear(zone, near: Vector3)
	self.zone = zone
	self.state = "Warn"
	self.warnUntil = os.clock() + Run.Diff().warning
	-- appear in the lair corner, facing the intruder
	local lair = zone.lair.Position
	self.model:PivotTo(CFrame.lookAt(lair + Vector3.new(0, ROOT_HEIGHT, 0), Vector3.new(near.X, lair.Y + ROOT_HEIGHT, near.Z)))
	self.model:SetAttribute("Anim", "idle")
	self.model.Parent = Run.Map and Run.Map:FindFirstChild("Monsters") or workspace
	Power.Flicker(lair, 20, 1.2)
	Sounds.Play("Whisper", self.head, { Volume = 1 })
	local players = {}
	for _, entry in occupants(zone) do
		table.insert(players, entry.player)
	end
	Run.Cinematic(players, "Whisper", { text = zone.warning or "اخرج... هذه الغرفة ليست لك." })
end

function Roomkeeper:Vanish(cooldown: number)
	if self.zone then
		self.cooldowns[self.zone.name] = os.clock() + cooldown
	end
	self.zone = nil
	self.state = "Idle"
	self.model.Parent = nil
end

function Roomkeeper:Step(_dt: number)
	local now = os.clock()
	if not Run.IsPlaying() then
		if self.zone then
			self:Vanish(0)
		end
		return
	end
	if not self.zone then
		for name, zone in Run.Zones do
			zone.name = name
			if (self.cooldowns[name] or 0) < now and (zone.enabled == nil or zone.enabled()) then
				local list = occupants(zone)
				if #list > 0 then
					self:Appear(zone, list[1].root.Position)
					return
				end
			end
		end
		return
	end
	local zone = self.zone
	if self.state == "Gone" then
		return
	end
	local list = occupants(zone)
	if #list == 0 then
		if self.state ~= "Leaving" then
			self.state = "Leaving"
			self.leaveAt = now + 0.6
			self.model:SetAttribute("Anim", "idle")
			Sounds.Play("Shriek", self.head)
		elseif now >= self.leaveAt then
			self:Vanish(3)
		end
		return
	end
	if self.state == "Leaving" then
		self.state = "Hunt"
	end
	if self.state == "Warn" and now >= self.warnUntil then
		self.state = "Hunt"
		Sounds.Play("Shriek", self.head)
	end
	if self.state ~= "Hunt" or now < self.nextStep then
		return
	end
	self.nextStep = now + cfg.StepInterval / Run.Diff().monsterSpeed
	-- nearest intruder
	local pos = self.root.Position
	local target, td = nil, math.huge
	for _, entry in list do
		local d = (entry.root.Position - pos).Magnitude
		if d < td then
			target, td = entry, d
		end
	end
	if not target then
		return
	end
	if td <= cfg.AttackRange then
		self.model:SetAttribute("Anim", "attack")
		Sounds.Play("Scream", self.head)
		Survival.Damage(target.player, cfg.Damage, "Roomkeeper")
		self.state = "Gone"
		task.delay(0.5, function()
			self:Vanish(6)
		end)
		return
	end
	-- skip toward the target, staying inside her room
	local goal = Vector3.new(target.root.Position.X, pos.Y, target.root.Position.Z)
	local dir = (goal - pos).Unit
	local stepLen = math.min(cfg.StepDistance, td - 2)
	local nextPos = pos + dir * stepLen
	nextPos = Vector3.new(
		math.clamp(nextPos.X, zone.min.X + 1.5, zone.max.X - 1.5),
		pos.Y,
		math.clamp(nextPos.Z, zone.min.Z + 1.5, zone.max.Z - 1.5)
	)
	self.model:PivotTo(CFrame.lookAt(nextPos, nextPos + dir))
	self.model:SetAttribute("Anim", "skip")
	Sounds.Play("Creak", self.root, { PlaybackSpeed = 0.5 + math.random() * 0.4 })
end

return Roomkeeper
