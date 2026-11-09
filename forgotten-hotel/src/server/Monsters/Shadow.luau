--!nonstrict
-- THE SHADOW: the hunter. States: Patrol -> Investigate (noise) -> Chase (sight) ->
-- Search (lost sight) -> Patrol. Uses direct steering when it has a clear line and
-- PathfindingService otherwise. Phases through doors. Relocates between floors when no
-- players are around. Fair rules: crouching in the dark keeps you nearly invisible,
-- flashlights are visible from far away, hiding works unless it SAW you hide.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)

local Services = script.Parent.Parent.Services
local Run = require(Services.Run)
local Power = require(Services.Power)
local Survival = require(Services.Survival)
local Hiding = require(Services.Hiding)
local Data = require(Services.Data)

local Rig = require(script.Parent.Rig)
local Senses = require(script.Parent.Senses)

local Shadow = {}
Shadow.__index = Shadow

local MODES = {
	upper = { "F3", "F2" },
	roam = { "G", "F1", "F2", "F3" },
	basement = { "B" },
	escape = { "B" },
}
local ROOT_HEIGHT = 4.6
local cfg = Config.Shadow

function Shadow.new()
	local self = setmetatable({}, Shadow)
	local model, root, head, humanoid = Rig.Shadow()
	self.model = model
	self.root = root
	self.head = head
	self.humanoid = humanoid
	self.breathing = head:FindFirstChild("Breathing")
	self.mode = "off"
	self.state = "Inactive"
	self.active = false
	self.floor = nil
	self.path = PathfindingService:CreatePath({
		AgentRadius = 1.6,
		AgentHeight = 8,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
		Costs = { Door = 2 },
	})
	self.waypoints = nil
	self.wpIndex = 1
	self.pathGoal = nil
	self.pathTime = 0
	self.computing = false
	self.lastPos = Vector3.zero
	self.stuckTime = 0
	self.target = nil
	self.lastSeen = 0
	self.lastSeenPos = nil
	self.investigatePos = nil
	self.searchPoint = nil
	self.searchUntil = 0
	self.attackReady = 0
	self.pauseUntil = 0
	self.patrolGoal = nil
	self.lonelySince = os.clock()
	self.stepSound = 0
	self.flickerAt = 0
	self.pendingNoise = nil
	self.dragTarget = nil
	return self
end

----------------------------------------------------------------------------------------
-- Spawning
----------------------------------------------------------------------------------------

function Shadow:Spawn(ground: Vector3)
	local container = Run.Map and Run.Map:FindFirstChild("Monsters") or workspace
	self.model:PivotTo(CFrame.new(ground + Vector3.new(0, ROOT_HEIGHT, 0)))
	self.model.Parent = container
	pcall(function()
		self.root:SetNetworkOwner(nil)
	end)
	self.active = true
	self.state = "Patrol"
	self.floor = Config.FloorAt(ground.Y + 1)
	self.waypoints = nil
	self.patrolGoal = nil
	self.lonelySince = os.clock()
	self.model:SetAttribute("Chasing", false)
	self.model:SetAttribute("TargetId", 0)
	if self.breathing then
		self.breathing:Play()
	end
end

function Shadow:Despawn()
	self.active = false
	self.state = "Inactive"
	self.target = nil
	self.model:SetAttribute("Chasing", false)
	self.model:SetAttribute("TargetId", 0)
	if self.breathing then
		self.breathing:Stop()
	end
	self.model.Parent = nil
end

local function nearestPlayerDistance(pos: Vector3): number
	local best = math.huge
	for _, entry in Run.Characters(true) do
		best = math.min(best, (entry.root.Position - pos).Magnitude)
	end
	return best
end

-- Moves to a floor allowed by the current mode, preferring floors with players but
-- always appearing out of sight (far from everyone).
function Shadow:Relocate(minDistance: number?)
	local floors = MODES[self.mode]
	if not floors then
		return
	end
	local occupied = Run.FloorsWithPlayers()
	local candidates = {}
	for _, floor in floors do
		if occupied[floor] and Run.Waypoints[floor] then
			table.insert(candidates, floor)
		end
	end
	if #candidates == 0 then
		for _, floor in floors do
			if Run.Waypoints[floor] then
				table.insert(candidates, floor)
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local floor = candidates[math.random(1, #candidates)]
	local nodes = Run.Waypoints[floor]
	local far, farthest, farthestDist = {}, nil, -1
	for _, node in nodes do
		local d = nearestPlayerDistance(node)
		if d >= (minDistance or 45) then
			table.insert(far, node)
		end
		if d > farthestDist then
			farthest, farthestDist = node, d
		end
	end
	local point = #far > 0 and far[math.random(1, #far)] or farthest
	if not point then
		return
	end
	if self.active then
		Power.Flicker(self.root.Position, 25, 0.8)
	end
	self:Despawn()
	self:Spawn(point)
end

function Shadow:SetMode(mode: string)
	self.mode = mode
	if mode == "off" then
		if self.active then
			self:Despawn()
		end
		return
	end
	local floors = MODES[mode]
	if not self.active or not table.find(floors, self.floor) then
		self:Relocate(mode == "escape" and 0 or 45)
	end
end

----------------------------------------------------------------------------------------
-- Navigation
----------------------------------------------------------------------------------------

local function clearLine(self, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { self.model }
	for _, entry in Run.Characters(true) do
		table.insert(filter, entry.character)
	end
	params.FilterDescendantsInstances = filter
	params.CollisionGroup = "Monsters" -- doors don't block the Shadow
	params.RespectCanCollide = true
	for _, h in { -3.4, 0 } do
		local a = from + Vector3.new(0, h, 0)
		local b = Vector3.new(to.X, a.Y, to.Z)
		if workspace:Raycast(a, b - a, params) then
			return false
		end
	end
	return true
end

function Shadow:ComputePath(goal: Vector3)
	if self.computing then
		return
	end
	self.computing = true
	task.spawn(function()
		local start = self.root.Position - Vector3.new(0, ROOT_HEIGHT - 1, 0)
		local ok = pcall(function()
			self.path:ComputeAsync(start, goal)
		end)
		self.computing = false
		self.pathGoal = goal
		self.pathTime = os.clock()
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.wpIndex = math.min(2, #self.waypoints)
		else
			self.waypoints = nil
		end
	end)
end

function Shadow:MoveTowards(goal: Vector3, speed: number)
	self.humanoid.WalkSpeed = speed * Run.Diff().monsterSpeed
	local pos = self.root.Position
	local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	if math.abs(goal.Y - (pos.Y - ROOT_HEIGHT)) < 6 and flat.Magnitude < 70 and clearLine(self, pos, goal) then
		self.waypoints = nil
		self.humanoid:MoveTo(goal)
		return
	end
	local stale = not self.pathGoal or (self.pathGoal - goal).Magnitude > 6 or os.clock() - self.pathTime > 2.5
	if (stale or not self.waypoints) and not self.computing then
		self:ComputePath(goal)
	end
	if self.waypoints then
		local wp = self.waypoints[self.wpIndex]
		if wp then
			local wpFlat = Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z)
			if wpFlat.Magnitude < 3 then
				self.wpIndex += 1
				wp = self.waypoints[self.wpIndex]
			end
		end
		if wp then
			self.humanoid:MoveTo(wp.Position)
		end
	end
end

local function reached(self, point: Vector3?, radius: number): boolean
	if not point then
		return true
	end
	local pos = self.root.Position
	return Vector3.new(point.X - pos.X, 0, point.Z - pos.Z).Magnitude < radius and math.abs(point.Y - (pos.Y - ROOT_HEIGHT)) < 6
end

----------------------------------------------------------------------------------------
-- Behaviour
----------------------------------------------------------------------------------------

function Shadow:StartChase(entry)
	self.state = "Chase"
	self.target = entry.player
	self.dragTarget = nil
	self.model:SetAttribute("Chasing", true)
	self.model:SetAttribute("TargetId", entry.player.UserId)
	Sounds.Play("Growl", self.head)
	Run.Cinematic(entry.player, "Spotted", nil)
end

function Shadow:EndChase(nextState: string)
	self.state = nextState
	self.model:SetAttribute("Chasing", false)
	self.model:SetAttribute("TargetId", 0)
	self.target = nil
	self.dragTarget = nil
	if nextState == "Search" then
		self.searchUntil = os.clock() + cfg.SearchTime
		self.searchPoint = self.lastSeenPos
	end
end

function Shadow:Attack(player: Player)
	local now = os.clock()
	self.attackReady = now + cfg.AttackCooldown
	self.pauseUntil = now + 1.1
	self.model:SetAttribute("Anim", "attack")
	Sounds.Play("Scream", self.head)
	Survival.Damage(player, cfg.Damage, "Shadow")
	task.delay(0.7, function()
		if self.model:GetAttribute("Anim") == "attack" then
			self.model:SetAttribute("Anim", "run")
		end
	end)
end

function Shadow:HearWorld(position: Vector3, loudness: number)
	if not self.active or loudness <= 0 or self.state == "Chase" then
		return
	end
	local dist = (position - self.root.Position).Magnitude
	if dist < 140 * loudness and math.abs(position.Y - self.root.Position.Y) < 14 then
		self.pendingNoise = position
	end
end

function Shadow:Step(dt: number)
	if not self.active then
		return
	end
	local now = os.clock()
	local pos = self.root.Position
	if pos.Y < -80 then
		self:Relocate(30)
		return
	end
	self.floor = Config.FloorAt(pos.Y - ROOT_HEIGHT + 1)
	local look = self.root.CFrame.LookVector
	local eye = self.head.Position

	-- PERCEPTION
	local seen = nil
	if self.mode == "escape" then
		local best, bestDist = nil, math.huge
		for _, entry in Run.Characters(false) do
			local d = (entry.root.Position - pos).Magnitude
			if d < bestDist and not entry.character:GetAttribute("Escaped") then
				best, bestDist = entry, d
			end
		end
		seen = best
	else
		seen = Senses.FindTarget(self.model, eye, look, self.state == "Chase")
	end
	if seen then
		if self.state ~= "Chase" then
			self:StartChase(seen)
		end
		self.target = seen.player
		self.lastSeen = now
		self.lastSeenPos = seen.root.Position
	end

	-- BEHAVIOUR
	local moveGoal, moveSpeed = nil, cfg.PatrolSpeed
	if self.state == "Chase" then
		local player = self.target
		local character = player and player.Character
		local troot = character and character:FindFirstChild("HumanoidRootPart")
		local thum = character and character:FindFirstChildOfClass("Humanoid")
		if not troot or not thum or thum.Health <= 0 or character:GetAttribute("Downed") then
			self:EndChase("Search")
		elseif character:GetAttribute("Hidden") then
			local hiddenFor = Hiding.HiddenFor(player)
			local sawIt = hiddenFor ~= nil and self.lastSeen >= (now - hiddenFor) - 0.35 and (self.lastSeenPos - pos).Magnitude < 32
			if sawIt or self.dragTarget == player then
				self.dragTarget = player
				local spot = Hiding.SpotOf(player)
				if spot then
					moveGoal, moveSpeed = spot.exit.Position, cfg.ChaseSpeed
					if reached(self, spot.exit.Position, 5) then
						Hiding.Exit(player, true)
						self:Attack(player)
						self.dragTarget = nil
						self.lastSeen = now
					end
				else
					self.dragTarget = nil
				end
			else
				Data.Award(player, "hide_seek")
				self:EndChase("Search")
			end
		elseif self.mode ~= "escape" and now - self.lastSeen > cfg.LoseTime then
			self:EndChase("Search")
		else
			moveGoal = seen and seen.root.Position or self.lastSeenPos
			moveSpeed = self.mode == "escape" and cfg.EscapeChaseSpeed or cfg.ChaseSpeed
			local dist = (troot.Position - pos).Magnitude
			if seen and dist <= cfg.AttackRange and now >= self.attackReady then
				self:Attack(player)
			end
		end
	end

	if self.state ~= "Chase" then
		local heard = Senses.Hear(pos)
		if heard then
			self.investigatePos = heard.root.Position
			self.state = "Investigate"
		elseif self.pendingNoise then
			self.investigatePos = self.pendingNoise
			self.state = "Investigate"
		end
		self.pendingNoise = nil
	end

	if self.state == "Investigate" then
		moveGoal, moveSpeed = self.investigatePos, cfg.InvestigateSpeed
		if reached(self, self.investigatePos, 4) then
			self.lastSeenPos = self.investigatePos
			self.state = "Search"
			self.searchUntil = now + cfg.SearchTime * 0.6
			self.searchPoint = self.investigatePos
		end
	elseif self.state == "Search" then
		if now > self.searchUntil then
			self.state = "Patrol"
			self.patrolGoal = nil
		else
			if not self.searchPoint or reached(self, self.searchPoint, 4) then
				local base = self.lastSeenPos or pos
				self.searchPoint = base + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
				self.searchPoint = Vector3.new(self.searchPoint.X, base.Y, self.searchPoint.Z)
			end
			moveGoal, moveSpeed = self.searchPoint, cfg.InvestigateSpeed * 0.8
		end
	elseif self.state == "Patrol" then
		local nodes = Run.Waypoints[self.floor]
		if nodes and #nodes > 0 then
			if not self.patrolGoal or reached(self, self.patrolGoal, 4) then
				if self.patrolGoal then
					self.pauseUntil = now + math.random(10, 30) / 10
				end
				-- drift toward players sometimes so encounters keep happening
				local pick = nodes[math.random(1, #nodes)]
				if math.random() < 0.35 then
					local best, bestD = pick, math.huge
					for _, node in nodes do
						local d = nearestPlayerDistance(node)
						if d < bestD and d > 18 then
							best, bestD = node, d
						end
					end
					pick = best
				end
				self.patrolGoal = pick
			end
			moveGoal, moveSpeed = self.patrolGoal, cfg.PatrolSpeed
		end
		-- relocate if nobody is on this floor
		local occupied = Run.FloorsWithPlayers()
		if occupied[self.floor] then
			self.lonelySince = now
		elseif now - self.lonelySince > cfg.RelocateTime then
			self.lonelySince = now
			self:Relocate(45)
			return
		end
	end

	-- MOVEMENT
	if now < self.pauseUntil or not moveGoal then
		self.humanoid:MoveTo(pos)
	else
		self:MoveTowards(moveGoal, moveSpeed)
	end

	-- stuck detection: phase forward along the path (it is a shadow after all)
	local moved = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(self.lastPos.X, 0, self.lastPos.Z)).Magnitude
	if moveGoal and now >= self.pauseUntil and moved < 0.15 then
		self.stuckTime += dt
		if self.stuckTime > 2.2 then
			self.stuckTime = 0
			local nextWp = self.waypoints and self.waypoints[self.wpIndex + 1]
			if nextWp then
				self.model:PivotTo(CFrame.new(nextWp.Position + Vector3.new(0, ROOT_HEIGHT, 0)))
				self.wpIndex += 1
			else
				self.patrolGoal = nil
				self.waypoints = nil
				self.pathGoal = nil
			end
		end
	else
		self.stuckTime = 0
	end
	self.lastPos = pos

	-- ANIMATION + EFFECTS
	local speed = Vector3.new(self.root.AssemblyLinearVelocity.X, 0, self.root.AssemblyLinearVelocity.Z).Magnitude
	if self.model:GetAttribute("Anim") ~= "attack" then
		self.model:SetAttribute("Anim", speed > 12 and "run" or (speed > 1 and "walk" or "idle"))
	end
	if speed > 1 and now > self.stepSound then
		self.stepSound = now + (speed > 12 and 0.33 or 0.6)
		Sounds.Play("HeavyStep", self.root)
	end
	if self.state == "Chase" and now > self.flickerAt then
		self.flickerAt = now + 1.4
		Power.Flicker(pos, 26, 0.9)
	end
end

return Shadow
