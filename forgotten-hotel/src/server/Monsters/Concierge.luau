--!nonstrict
-- THE CONCIERGE: Halden, the head concierge, bound to the hotel. He never attacks. He
-- appears at a distance (behind the reception desk, at corridor ends...), turns to face
-- you, and vanishes when approached or stared at for too long. Builds dread, and in the
-- story he hands over the basement key.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)

local Services = script.Parent.Parent.Services
local Run = require(Services.Run)
local Power = require(Services.Power)

local Rig = require(script.Parent.Rig)
local Senses = require(script.Parent.Senses)

local Concierge = {}
Concierge.__index = Concierge

local cfg = Config.Concierge
local ROOT_HEIGHT = 3.1

function Concierge.new()
	local self = setmetatable({}, Concierge)
	local model, root, head = Rig.Concierge()
	self.model = model
	self.root = root
	self.head = head
	root.Anchored = true
	self.visible = false
	self.enabled = false
	self.nextAppear = os.clock() + 25
	self.until_ = 0
	self.stare = {}
	self.scripted = false
	return self
end

function Concierge:Show(cf: CFrame, duration: number?, scripted: boolean?)
	local container = Run.Map and Run.Map:FindFirstChild("Monsters") or workspace
	self.model:PivotTo(cf + Vector3.new(0, ROOT_HEIGHT, 0))
	self.model.Parent = container
	self.model:SetAttribute("Anim", "stand")
	self.visible = true
	self.scripted = scripted == true
	self.until_ = os.clock() + (duration or cfg.Lifetime)
	self.stare = {}
	Sounds.Play("Whisper", self.head)
end

function Concierge:Hide(effect: boolean?)
	if not self.visible then
		return
	end
	if effect and self.root.Parent then
		Power.Flicker(self.root.Position, 18, 0.6)
		Sounds.Play("Static", self.head, { Looped = false })
	end
	self.visible = false
	self.scripted = false
	self.model.Parent = nil
end

local function facePlayers(self)
	local pos = self.root.Position
	local nearest, nd = nil, math.huge
	for _, entry in Run.Characters(true) do
		local d = (entry.root.Position - pos).Magnitude
		if d < nd then
			nearest, nd = entry, d
		end
	end
	if nearest then
		local target = Vector3.new(nearest.root.Position.X, pos.Y, nearest.root.Position.Z)
		if (target - pos).Magnitude > 0.5 then
			self.model:PivotTo(CFrame.lookAt(pos, target))
		end
	end
	return nearest, nd
end

local function chooseSpot(self)
	local occupied = Run.FloorsWithPlayers()
	local options = {}
	for _, spot in Run.ConciergeSpots do
		if occupied[spot.floor] then
			local pos = spot.cf.Position + Vector3.new(0, 6, 0)
			local tooClose = false
			local visibleTo = false
			for _, entry in Run.Characters(false) do
				local d = (entry.root.Position - spot.cf.Position).Magnitude
				if d < cfg.MinDistance then
					tooClose = true
				elseif d < 90 and Senses.LineOfSight(pos, entry.character, self.model) then
					visibleTo = true
				end
			end
			if not tooClose then
				table.insert(options, { spot = spot, weight = visibleTo and 3 or 1 })
			end
		end
	end
	if #options == 0 then
		return nil
	end
	local total = 0
	for _, o in options do
		total += o.weight
	end
	local r = math.random() * total
	for _, o in options do
		r -= o.weight
		if r <= 0 then
			return o.spot
		end
	end
	return options[1].spot
end

function Concierge:Step(dt: number)
	local now = os.clock()
	if self.visible then
		local _, nearestDist = facePlayers(self)
		if not self.scripted then
			if nearestDist < cfg.VanishDistance or now > self.until_ then
				self:Hide(true)
				return
			end
			-- vanish when someone stares at him too long
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local head = character and character:FindFirstChild("Head")
				if head then
					local toMe = (self.head.Position - head.Position)
					local facing = head.CFrame.LookVector:Dot(toMe.Unit)
					if facing > 0.96 and toMe.Magnitude < 90 then
						self.stare[player] = (self.stare[player] or 0) + dt
						if self.stare[player] > cfg.StareTime then
							self:Hide(true)
							return
						end
					end
				end
			end
		elseif now > self.until_ then
			self:Hide(true)
		end
		return
	end
	if not self.enabled or not Run.IsPlaying() then
		return
	end
	if now >= self.nextAppear then
		local rate = Run.Diff().eventRate
		self.nextAppear = now + math.random(cfg.MinInterval, cfg.MaxInterval) / rate
		local spot = chooseSpot(self)
		if spot then
			self:Show(spot.cf)
		end
	end
end

return Concierge
