--!nonstrict
-- Sound library.
--
-- Out of the box every sound uses audio files that ship with the Roblox client
-- (rbxasset://sounds/...), shaped with pitch/volume/looping so the game is fully audible
-- without uploading anything. To make the game sound truly professional, replace the
-- `id` values with "rbxassetid://<id>" of horror audio you own or that is licensed for
-- use (Creator Store / your own uploads). Nothing else needs to change.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sounds = {}

local FALL = "rbxasset://sounds/action_falling.mp3"
local SWIM = "rbxasset://sounds/action_swim.mp3"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local GETUP = "rbxasset://sounds/action_get_up.mp3"
local WATER = "rbxasset://sounds/impact_water.mp3"
local UHH = "rbxasset://sounds/uuhhh.mp3"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local SLASH = "rbxasset://sounds/swordslash.wav"
local UNSHEATH = "rbxasset://sounds/unsheath.wav"

Sounds.Library = {
	-- Ambience / music (2D, played on the client)
	Wind = { id = FALL, volume = 0.35, pitch = 0.5, looped = true, group = "Ambience" },
	Rain = { id = SWIM, volume = 0.22, pitch = 0.55, looped = true, group = "Ambience" },
	Drone = { id = FALL, volume = 0.3, pitch = 0.16, looped = true, group = "Music" },
	ChaseLayer = { id = FALL, volume = 0, pitch = 0.3, looped = true, group = "Music" },
	Hum = { id = CLICK, volume = 0.08, pitch = 0.22, looped = true, group = "Ambience" },
	Heartbeat = { id = LAND, volume = 0.9, pitch = 0.42, group = "SFX" },
	-- 3D world sounds
	Footstep = { id = STEP, volume = 0.5, pitch = 0.75, group = "SFX", range = 60 },
	HeavyStep = { id = LAND, volume = 1.1, pitch = 0.32, group = "SFX", range = 90 },
	DoorOpen = { id = GETUP, volume = 0.7, pitch = 0.45, group = "SFX", range = 50 },
	DoorClose = { id = LAND, volume = 0.8, pitch = 0.6, group = "SFX", range = 50 },
	DoorSlam = { id = LAND, volume = 2, pitch = 0.3, group = "SFX", range = 160 },
	Creak = { id = GETUP, volume = 0.9, pitch = 0.28, group = "SFX", range = 60 },
	Locked = { id = CLICK, volume = 0.6, pitch = 0.55, group = "SFX", range = 30 },
	Unlock = { id = CLICK, volume = 0.7, pitch = 1.15, group = "SFX", range = 30 },
	Pickup = { id = PING, volume = 0.35, pitch = 1.5, group = "SFX", range = 20 },
	Paper = { id = SWIM, volume = 0.4, pitch = 2.4, group = "SFX", range = 15 },
	Ding = { id = PING, volume = 0.9, pitch = 0.8, group = "SFX", range = 80 },
	ElevatorRun = { id = FALL, volume = 0.6, pitch = 0.22, looped = true, group = "SFX", range = 40 },
	Whisper = { id = SWIM, volume = 0.45, pitch = 2.2, group = "SFX", range = 40 },
	Scream = { id = UHH, volume = 1.3, pitch = 0.5, group = "SFX", range = 200 },
	Growl = { id = UHH, volume = 1.1, pitch = 0.28, group = "SFX", range = 90 },
	Shriek = { id = UHH, volume = 1.2, pitch = 1.6, group = "SFX", range = 120 },
	Breathing = { id = FALL, volume = 0.7, pitch = 0.4, looped = true, group = "SFX", range = 45 },
	Static = { id = CLICK, volume = 0.35, pitch = 0.38, looped = true, group = "SFX", range = 30 },
	PhoneRing = { id = PING, volume = 1, pitch = 1.9, group = "SFX", range = 90 },
	Thunder = { id = WATER, volume = 2.2, pitch = 0.12, group = "Ambience" },
	Click = { id = CLICK, volume = 0.5, pitch = 1, group = "SFX", range = 20 },
	Hit = { id = SLASH, volume = 1.1, pitch = 0.45, group = "SFX", range = 50 },
	Lever = { id = UNSHEATH, volume = 0.9, pitch = 0.45, group = "SFX", range = 50 },
	Generator = { id = FALL, volume = 1.3, pitch = 0.13, looped = true, group = "SFX", range = 120 },
	GeneratorStart = { id = UNSHEATH, volume = 2, pitch = 0.25, group = "SFX", range = 220 },
	Crash = { id = WATER, volume = 1.4, pitch = 0.4, group = "SFX", range = 90 },
	Alarm = { id = PING, volume = 1.1, pitch = 0.55, group = "SFX", range = 300 },
	Heart = { id = LAND, volume = 1.5, pitch = 0.25, group = "SFX", range = 70 },
	UIClick = { id = CLICK, volume = 0.4, pitch = 1.3, group = "SFX" },
	UIHover = { id = CLICK, volume = 0.15, pitch = 2, group = "SFX" },
	Sting = { id = UHH, volume = 0.9, pitch = 0.22, group = "Music" },
}

function Sounds.Group(name: string): SoundGroup?
	local group = SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		return group
	end
	return nil
end

-- Creates (but does not play) a configured Sound.
function Sounds.Make(name: string, parent: Instance?, overrides: { [string]: any }?): Sound?
	local def = Sounds.Library[name]
	if not def then
		warn("[Sounds] unknown sound", name)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume or 0.5
	sound.PlaybackSpeed = def.pitch or 1
	sound.Looped = def.looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = def.range or 80
	sound.SoundGroup = Sounds.Group(def.group or "SFX")
	if overrides then
		for key, value in overrides do
			sound[key] = value
		end
	end
	sound.Parent = parent or SoundService
	return sound
end

-- Plays a one-shot sound attached to `parent` (3D if parent is a BasePart/Attachment).
function Sounds.Play(name: string, parent: Instance?, overrides: { [string]: any }?): Sound?
	local sound = Sounds.Make(name, parent, overrides)
	if not sound then
		return nil
	end
	sound:Play()
	if not sound.Looped then
		Debris:AddItem(sound, 12)
	end
	return sound
end

-- Plays a one-shot sound at a world position.
function Sounds.PlayAt(name: string, position: Vector3, overrides: { [string]: any }?): Sound?
	local attachment = Instance.new("Attachment")
	attachment.Name = "SoundEmitter"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	Debris:AddItem(attachment, 12)
	return Sounds.Play(name, attachment, overrides)
end

return Sounds
