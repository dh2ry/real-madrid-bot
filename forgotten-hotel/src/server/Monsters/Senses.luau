--!nonstrict
-- Perception shared by all monsters: line of sight, vision ranges (flashlight makes you
-- visible from far away, crouching in the dark keeps you hidden), and hearing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Run = require(script.Parent.Parent.Services.Run)

local Senses = {}

local function characterList(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- True when nothing solid blocks the line between `from` and the target character.
function Senses.LineOfSight(from: Vector3, character: Model, ignore: Instance): boolean
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = characterList()
	table.insert(filter, ignore)
	params.FilterDescendantsInstances = filter
	params.RespectCanCollide = true
	local target = (head :: BasePart).Position
	local result = workspace:Raycast(from, target - from, params)
	return result == nil
end

function Senses.SightRange(character: Model): number
	local diff = Run.Diff()
	local cfg = Config.Shadow
	local range
	if character:GetAttribute("Lit") then
		range = cfg.SightRange
	elseif character:GetAttribute("Noise") ~= nil and (character:GetAttribute("Noise") :: number) <= Config.Movement.Noise.crouch then
		range = cfg.CrouchSightRange
	else
		range = cfg.DarkSightRange
	end
	return range * diff.sight
end

-- Best visible target (closest). `omni` ignores the field-of-view cone (used mid-chase).
function Senses.FindTarget(monster: Model, eye: Vector3, look: Vector3, omni: boolean?)
	local best, bestDist = nil, math.huge
	for _, entry in Run.Characters(false) do
		local character = entry.character
		if not character:GetAttribute("Hidden") then
			local offset = entry.root.Position - eye
			local dist = offset.Magnitude
			local range = Senses.SightRange(character)
			if omni then
				range = math.max(range, Config.Shadow.DarkSightRange * 1.6)
			end
			if dist <= range and dist < bestDist then
				local inCone = omni or dist < 8 or look:Dot(offset.Unit) >= Config.Shadow.FieldOfView
				if inCone and math.abs(offset.Y) < 12 and Senses.LineOfSight(eye, character, monster) then
					best, bestDist = entry, dist
				end
			end
		end
	end
	return best, bestDist
end

-- Loudest audible player within hearing range.
function Senses.Hear(position: Vector3)
	local best, bestScore = nil, 0
	local diff = Run.Diff()
	for _, entry in Run.Characters(true) do
		local noise = entry.character:GetAttribute("Noise") or 0
		if noise > 0 and not entry.character:GetAttribute("Hidden") then
			local dist = (entry.root.Position - position).Magnitude
			local radius = Config.Shadow.HearRange * noise * diff.sight
			if dist < radius and math.abs(entry.root.Position.Y - position.Y) < 12 then
				local score = 1 - dist / radius
				if score > bestScore then
					best, bestScore = entry, score
				end
			end
		end
	end
	return best
end

return Senses
