--!nonstrict
-- Applies player settings locally (graphics, audio, camera) and syncs them to the
-- server profile (debounced).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local State = require(script.Parent.State)

local Settings = {}
local saveToken = 0

local function setEmitters(tag: string, enabled: boolean)
	for _, emitter in CollectionService:GetTagged(tag) do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = enabled
		end
	end
end

function Settings.Apply()
	local s = State.Settings
	local master = s.master
	for name, key in { SFX = "sfx", Music = "music", Ambience = "ambience" } do
		local group = SoundService:FindFirstChild(name)
		if group and group:IsA("SoundGroup") then
			group.Volume = master * s[key]
		end
	end
	setEmitters("AmbientParticles", s.particles)
	setEmitters("Rain", s.rain)
	Lighting.GlobalShadows = s.shadows
	Lighting.ExposureCompensation = s.brightness
	State.Changed:Fire("SettingsApplied", s)
end

function Settings.Get(key: string)
	return State.Settings[key]
end

function Settings.Set(key: string, value: any)
	local range = Config.SettingRanges[key]
	if range and typeof(value) == "number" then
		value = math.clamp(math.floor(value * 100 + 0.5) / 100, range[1], range[2])
	end
	State.Settings[key] = value
	Settings.Apply()
	saveToken += 1
	local token = saveToken
	task.delay(1.2, function()
		if token == saveToken then
			Net.Event("Settings"):FireServer(State.Settings)
		end
	end)
end

function Settings.Init()
	CollectionService:GetInstanceAddedSignal("AmbientParticles"):Connect(function(emitter)
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = State.Settings.particles
		end
	end)
	CollectionService:GetInstanceAddedSignal("Rain"):Connect(function(emitter)
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = State.Settings.rain
		end
	end)
	local loadedOnce = false
	State.Changed:Connect(function(key, profile)
		if key == "Profile" and profile and not loadedOnce then
			loadedOnce = true
			for k, v in profile.settings or {} do
				if Config.DefaultSettings[k] ~= nil then
					State.Settings[k] = v
				end
			end
			Settings.Apply()
		end
	end)
	Settings.Apply()
end

return Settings
