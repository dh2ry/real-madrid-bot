--!nonstrict
-- Dynamic soundscape: wind & rain outside, a low drone inside, electrical hum in the
-- basement, a chase layer and heartbeat driven by monster threat, and random distant
-- creaks/whispers/footsteps around the player (3D, local only).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
local State = require(script.Parent.State)

local Audio = {}
local player = Players.LocalPlayer
local layers = {}
local nextBeat = 0
local nextAmbient = os.clock() + 15

local function layer(name: string)
	local sound = Sounds.Make(name, nil)
	if sound then
		sound.Volume = 0
		sound:Play()
	end
	layers[name] = { sound = sound, base = Sounds.Library[name].volume or 0.5 }
end

local function fade(name: string, target: number, dt: number, speed: number?)
	local l = layers[name]
	if l and l.sound then
		local goal = l.base * target
		l.sound.Volume += (goal - l.sound.Volume) * math.min(1, dt * (speed or 1.5))
	end
end

local function computeThreat(root: BasePart): number
	local threat = 0
	for _, model in CollectionService:GetTagged("MonsterRig") do
		local mroot = model.PrimaryPart
		if mroot and model:IsDescendantOf(workspace) then
			local d = (mroot.Position - root.Position).Magnitude
			local style = model:GetAttribute("Style")
			if style == "shadow" then
				if model:GetAttribute("Chasing") and model:GetAttribute("TargetId") == player.UserId then
					threat = math.max(threat, 1)
				elseif d < 55 then
					threat = math.max(threat, (1 - d / 55) * (model:GetAttribute("Chasing") and 0.85 or 0.55))
				end
			elseif style == "roomkeeper" and d < 25 then
				threat = math.max(threat, 0.8)
			elseif style == "concierge" and d < 40 then
				threat = math.max(threat, 0.25)
			end
		end
	end
	return threat
end

function Audio.Init()
	for _, name in { "Wind", "Rain", "Drone", "ChaseLayer", "Hum" } do
		layer(name)
	end
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local pos = root and root.Position or workspace.CurrentCamera.CFrame.Position
		local inside = Config.IsInside(pos) and not (State.MenuOpen and not State.InRun())
		local floor = Config.FloorAt(pos.Y)
		fade("Wind", inside and 0.25 or 1, dt)
		fade("Rain", inside and 0.35 or 1.2, dt)
		fade("Drone", inside and (floor == "F3" and 1.4 or 1) or 0.35, dt, 0.6)
		fade("Hum", (inside and floor == "B") and 1 or 0, dt)
		local threat = root and computeThreat(root) or 0
		State.Threat = threat
		local chaseVolume = threat > 0.95 and 0.9 or threat * 0.4
		layers.ChaseLayer.base = 1
		fade("ChaseLayer", chaseVolume, dt, threat > 0.95 and 4 or 1)
		-- heartbeat (lub-dub) speeds up with threat
		local now = os.clock()
		if threat > 0.25 and now >= nextBeat then
			local interval = 1.1 - threat * 0.65
			nextBeat = now + interval
			Sounds.Play("Heartbeat", nil, { Volume = 0.4 + threat * 0.6 })
			task.delay(0.18, function()
				Sounds.Play("Heartbeat", nil, { Volume = 0.3 + threat * 0.5, PlaybackSpeed = 0.38 })
			end)
		end
		-- random distant sounds while inside
		if inside and State.InRun() and now >= nextAmbient then
			nextAmbient = now + math.random(16, 36)
			local names = { "Creak", "Whisper", "Footstep", "DoorClose", "Static" }
			local name = names[math.random(1, #names)]
			local a = math.random() * math.pi * 2
			local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * math.random(14, 30)
			Sounds.PlayAt(name, pos + offset, { Volume = 0.25 + math.random() * 0.2, Looped = false })
		end
	end)
end

return Audio
