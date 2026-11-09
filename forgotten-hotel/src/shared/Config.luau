--!nonstrict
-- Central tuning values for The Forgotten Hotel. Everything gameplay-related that a
-- designer might want to tweak lives here so it can be balanced without touching logic.

local Config = {}

Config.GameName = "THE FORGOTTEN HOTEL"
Config.GameNameArabic = "الفندق المنسي"
Config.HotelName = "GRAND AURELIA HOTEL"
Config.MaxPlayers = 6
Config.DataStoreName = "ForgottenHotel_v1"
Config.TotalDocuments = 12

-- Vertical layout (walkable floor surface Y of every level).
Config.Floors = { B = -14, G = 0, F1 = 16, F2 = 32, F3 = 48 }
Config.FloorOrder = { "B", "G", "F1", "F2", "F3" }
Config.FloorNames = { B = "القبو", G = "الطابق الأرضي", F1 = "الطابق الأول", F2 = "الطابق الثاني", F3 = "الطابق الثالث" }
Config.ElevatorFloors = { "G", "F1", "F2", "F3" }
Config.ElevatorLabels = { G = "أ", F1 = "1", F2 = "2", F3 = "3" }
Config.Footprint = { minX = -60, maxX = 60, minZ = -50, maxZ = 50 }

function Config.FloorAt(y: number): string
	if y < -2 then
		return "B"
	elseif y < 15 then
		return "G"
	elseif y < 31 then
		return "F1"
	elseif y < 47 then
		return "F2"
	end
	return "F3"
end

function Config.IsInside(pos: Vector3): boolean
	local f = Config.Footprint
	if pos.X < -100 and pos.Y < -2 then
		return true -- escape tunnel
	end
	return pos.X > f.minX - 1 and pos.X < f.maxX + 1 and pos.Z > f.minZ - 1 and pos.Z < f.maxZ + 1
end

Config.Palette = {
	Burgundy = Color3.fromRGB(92, 24, 34),
	DeepBurgundy = Color3.fromRGB(58, 14, 22),
	Black = Color3.fromRGB(14, 12, 14),
	Charcoal = Color3.fromRGB(32, 29, 31),
	Gold = Color3.fromRGB(178, 142, 74),
	DimGold = Color3.fromRGB(120, 96, 52),
	DarkBrown = Color3.fromRGB(52, 34, 24),
	Walnut = Color3.fromRGB(78, 50, 34),
	ColdBlue = Color3.fromRGB(120, 160, 220),
	Bone = Color3.fromRGB(214, 204, 182),
	Paper = Color3.fromRGB(222, 210, 180),
	Blood = Color3.fromRGB(74, 6, 8),
	DryBlood = Color3.fromRGB(52, 10, 10),
	Marble = Color3.fromRGB(28, 24, 26),
	Plaster = Color3.fromRGB(86, 88, 94),
	Concrete = Color3.fromRGB(70, 70, 72),
	Rust = Color3.fromRGB(96, 54, 36),
	Warm = Color3.fromRGB(255, 196, 132),
	Emergency = Color3.fromRGB(255, 40, 30),
}

Config.Movement = {
	CrouchSpeed = 6,
	WalkSpeed = 12,
	SprintSpeed = 21,
	DownedSpeed = 3,
	StaminaMax = 100,
	StaminaDrain = 20, -- per second while sprinting
	StaminaRegen = 13, -- per second otherwise
	ExhaustRecover = 30, -- stamina needed to sprint again after exhausting
	Noise = { idle = 0, crouch = 0.15, walk = 0.45, sprint = 1 },
}

Config.Flashlight = {
	Range = 52,
	Angle = 52,
	Brightness = 2.6,
	BatteryMax = 100,
	LowBattery = 15,
	BatteryItemRestore = 100,
}

Config.Health = {
	Max = 100,
	RegenPerSecond = 0.6,
	RegenDelay = 10,
	BandageHeal = 35,
	ReviveHealth = 45,
	ReviveHoldTime = 3.5,
}

Config.Difficulty = {
	Easy = {
		label = "سهل",
		monsterSpeed = 0.85,
		damage = 0.6,
		eventRate = 0.7,
		sight = 0.8,
		battery = 0.25,
		downedTime = 60,
		warning = 4,
		reward = 0.75,
	},
	Normal = {
		label = "عادي",
		monsterSpeed = 1,
		damage = 1,
		eventRate = 1,
		sight = 1,
		battery = 0.42,
		downedTime = 45,
		warning = 3,
		reward = 1,
	},
	Nightmare = {
		label = "كابوس",
		monsterSpeed = 1.12,
		damage = 1.45,
		eventRate = 1.4,
		sight = 1.25,
		battery = 0.62,
		downedTime = 30,
		warning = 2,
		reward = 1.6,
	},
}
Config.DifficultyOrder = { "Easy", "Normal", "Nightmare" }

Config.Shadow = {
	PatrolSpeed = 9,
	InvestigateSpeed = 13,
	ChaseSpeed = 18.5, -- players sprint at 21 but stamina runs out
	EscapeChaseSpeed = 17.5,
	Damage = 34,
	AttackRange = 5,
	AttackCooldown = 1.7,
	SightRange = 80, -- vs. players with flashlight on
	DarkSightRange = 34, -- vs. players in the dark
	CrouchSightRange = 20,
	FieldOfView = 0.25, -- dot product threshold (wide)
	HearRange = 56, -- multiplied by player noise
	LoseTime = 4.5,
	SearchTime = 7,
	RelocateTime = 30,
}

Config.Roomkeeper = {
	StepDistance = 3.4,
	StepInterval = 0.34,
	Damage = 40,
	AttackRange = 5,
}

Config.Concierge = {
	MinInterval = 35,
	MaxInterval = 85,
	MinDistance = 32,
	VanishDistance = 17,
	Lifetime = 12,
	StareTime = 2.2,
}

-- Puzzle solutions. Every one of them is discoverable through in-game clues:
--  Security: "Est. 1931" plaque above the lobby arch + reception memo.
--  ManagerSafe: Journal I says "her birthday, day then month"; the photograph says 27 April.
--  Laboratory: Journal III / maintenance note "the night she vanished" = 7 March 1974 (DDMM).
--  Library books: housekeeping rhyme "blood, crown, cold sky, the night".
Config.Codes = {
	Security = "1931",
	ManagerSafe = "2704",
	Laboratory = "0703",
}
Config.BookOrder = { "Red", "Gold", "Blue", "Black" }

Config.Rewards = {
	escape = 100,
	liberation = 200,
	concierge = 120,
	secret = 300,
	perDocument = 10,
}

-- Player settings (saved in the profile). Numbers are clamped to [min, max] on the server.
Config.DefaultSettings = {
	cameraMode = "first", -- "first" | "third"
	fov = 75,
	sensitivity = 1,
	headBob = true,
	particles = true,
	rain = true,
	shadows = true,
	brightness = 0,
	master = 1,
	music = 0.7,
	sfx = 1,
	ambience = 0.8,
}
Config.SettingRanges = {
	fov = { 60, 100 },
	sensitivity = { 0.2, 3 },
	brightness = { -0.2, 0.4 },
	master = { 0, 1 },
	music = { 0, 1 },
	sfx = { 0, 1 },
	ambience = { 0, 1 },
}

return Config
