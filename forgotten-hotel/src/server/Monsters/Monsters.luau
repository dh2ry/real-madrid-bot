--!nonstrict
-- Orchestrates the three monsters and their update loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Run = require(script.Parent.Parent.Services.Run)
local Shadow = require(script.Parent.Shadow)
local Concierge = require(script.Parent.Concierge)
local Roomkeeper = require(script.Parent.Roomkeeper)

local Monsters = {}
Monsters.Shadow = nil
Monsters.Concierge = nil
Monsters.Roomkeeper = nil

function Monsters.SetShadowMode(mode: string)
	if Monsters.Shadow then
		Monsters.Shadow:SetMode(mode)
	end
end

function Monsters.ShadowMode(): string
	return Monsters.Shadow and Monsters.Shadow.mode or "off"
end

function Monsters.SetConcierge(enabled: boolean)
	if Monsters.Concierge then
		Monsters.Concierge.enabled = enabled
		if not enabled then
			Monsters.Concierge:Hide(false)
		end
	end
end

-- Builds fresh monsters (called after every map build).
function Monsters.Reset()
	if Monsters.Shadow then
		Monsters.Shadow:Despawn()
		Monsters.Shadow.model:Destroy()
	end
	if Monsters.Concierge then
		Monsters.Concierge.model:Destroy()
	end
	if Monsters.Roomkeeper then
		Monsters.Roomkeeper.model:Destroy()
	end
	Monsters.Shadow = Shadow.new()
	Monsters.Concierge = Concierge.new()
	Monsters.Roomkeeper = Roomkeeper.new()
end

-- Places the Shadow at an exact spot (scripted scenes).
function Monsters.PlaceShadow(mode: string, ground: Vector3)
	local shadow = Monsters.Shadow
	if not shadow then
		return
	end
	shadow.mode = mode
	shadow:Despawn()
	shadow:Spawn(ground)
end

function Monsters.Init()
	Run.Noise:Connect(function(position: Vector3, loudness: number)
		if Monsters.Shadow then
			Monsters.Shadow:HearWorld(position, loudness)
		end
	end)
	local function loop(interval: number, getter)
		task.spawn(function()
			local last = os.clock()
			while true do
				task.wait(interval)
				local now = os.clock()
				local monster = getter()
				if monster and Run.IsPlaying() then
					local ok, err = pcall(monster.Step, monster, now - last)
					if not ok then
						warn("[Monsters] step error:", err)
					end
				end
				last = now
			end
		end)
	end
	loop(0.1, function()
		return Monsters.Shadow
	end)
	loop(0.2, function()
		return Monsters.Concierge
	end)
	loop(0.1, function()
		return Monsters.Roomkeeper
	end)
end

Monsters.Config = Config
return Monsters
