--!nonstrict
-- Furniture and set-dressing library. Every builder takes a CFrame placed on the floor at
-- the prop's centre with its LookVector pointing to the prop's front (local -Z).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)

local P, D, Cyl, Ball = Build.P, Build.D, Build.Cyl, Build.Ball
local C = Config.Palette
local M = Enum.Material

local Props = {}

local function at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local function warmLight(parent, range, brightness, zone, shadows)
	return Build.Light(parent, "PointLight", {
		Range = range,
		Brightness = brightness,
		Color = C.Warm,
		Shadows = shadows == true,
	}, zone)
end

----------------------------------------------------------------------------------------
-- Lighting fixtures
----------------------------------------------------------------------------------------

-- `pos` is the ceiling attachment point.
function Props.Chandelier(parent, pos: Vector3, zone: string, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Chandelier")
	local drop = opts.drop or 3
	local gold = opts.color or C.Gold
	D(m, Vector3.new(0.25, drop, 0.25), CFrame.new(pos - Vector3.new(0, drop / 2, 0)), C.DimGold, M.Metal)
	local center = pos - Vector3.new(0, drop + 0.6, 0)
	local body = Ball(m, 1.3, center, gold, M.Foil, { decor = true, name = "Body" })
	local arms = opts.arms or 8
	local radius = opts.radius or 2.4
	for i = 1, arms do
		local a = (i / arms) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local armCf = CFrame.lookAt(center + dir * radius / 2, center + dir * radius)
		D(m, Vector3.new(0.15, 0.15, radius), armCf, gold, M.Metal)
		local tip = center + dir * radius
		Cyl(m, 0.4, 0.3, tip + Vector3.new(0, 0.15, 0), gold, M.Metal, { decor = true })
		Cyl(m, 0.22, 0.6, tip + Vector3.new(0, 0.6, 0), C.Bone, M.Neon, { decor = true, name = "Bulb" })
		D(m, Vector3.new(0.18, 0.5, 0.18), CFrame.new(tip - Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, a, math.rad(45)), Color3.fromRGB(200, 210, 220), M.Glass, { transparency = 0.35 })
	end
	D(m, Vector3.new(0.25, 1.2, 0.25), CFrame.new(center - Vector3.new(0, 1, 0)), Color3.fromRGB(200, 210, 220), M.Glass, { transparency = 0.3 })
	warmLight(body, opts.range or 30, opts.brightness or 1.5, zone, opts.shadows)
	Build.Tag(m, "Chandelier")
	return m
end

-- `cf` sits on the wall surface facing into the room.
function Props.Sconce(parent, cf: CFrame, zone: string, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Sconce")
	D(m, Vector3.new(0.6, 1.2, 0.15), cf * CFrame.new(0, 0, -0.08), C.Gold, M.Metal)
	D(m, Vector3.new(0.15, 0.15, 0.7), cf * CFrame.new(0, -0.1, -0.4), C.Gold, M.Metal)
	local shade = Cyl(m, 0.7, 0.8, cf * CFrame.new(0, 0.35, -0.75), opts.shade or Color3.fromRGB(230, 200, 160), M.Neon, { decor = true, transparency = 0.2 })
	Build.Light(shade, "PointLight", {
		Range = opts.range or 13,
		Brightness = opts.brightness or 0.9,
		Color = opts.color or C.Warm,
		Shadows = false,
	}, zone, opts.powered)
	return m
end

-- Simple hanging lamp, `pos` = ceiling point.
function Props.Pendant(parent, pos: Vector3, zone: string, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Pendant")
	local drop = opts.drop or 2
	D(m, Vector3.new(0.1, drop, 0.1), CFrame.new(pos - Vector3.new(0, drop / 2, 0)), C.Black, M.Metal)
	local shadePos = pos - Vector3.new(0, drop + 0.4, 0)
	Cyl(m, 1.8, 0.8, shadePos, opts.shade or C.DimGold, M.Metal, { decor = true })
	local bulb = Ball(m, 0.6, shadePos - Vector3.new(0, 0.45, 0), opts.bulb or C.Bone, M.Neon, { decor = true, name = "Bulb" })
	Build.Light(bulb, "PointLight", {
		Range = opts.range or 18,
		Brightness = opts.brightness or 1.1,
		Color = opts.color or C.Warm,
		Shadows = opts.shadows == true,
	}, zone, opts.powered)
	return m
end

-- Caged industrial lamp for the basement.
function Props.CageLamp(parent, pos: Vector3, zone: string, opts)
	opts = opts or {}
	local m = Build.Model(parent, "CageLamp")
	D(m, Vector3.new(1.2, 0.3, 1.2), CFrame.new(pos - Vector3.new(0, 0.15, 0)), C.Rust, M.CorrodedMetal)
	local bulb = Ball(m, 0.7, pos - Vector3.new(0, 0.7, 0), opts.bulb or Color3.fromRGB(210, 220, 200), M.Neon, { decor = true, name = "Bulb" })
	for i = 0, 3 do
		D(m, Vector3.new(0.08, 1, 0.08), CFrame.new(pos - Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0.45, 0, 0), C.Charcoal, M.Metal)
	end
	Build.Light(bulb, "PointLight", {
		Range = opts.range or 20,
		Brightness = opts.brightness or 1,
		Color = opts.color or Color3.fromRGB(190, 210, 255),
		Shadows = opts.shadows == true,
	}, zone, opts.powered)
	return m
end

-- Always-lit candle (not connected to power).
function Props.Candle(parent, pos: Vector3, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Candle")
	local h = opts.height or 0.8
	Cyl(m, 0.25, h, pos + Vector3.new(0, h / 2, 0), C.Bone, M.SmoothPlastic, { decor = true })
	local flame = Ball(m, 0.18, pos + Vector3.new(0, h + 0.12, 0), Color3.fromRGB(255, 180, 90), M.Neon, { decor = true })
	if opts.light ~= false then
		Build.Light(flame, "PointLight", { Range = opts.range or 8, Brightness = 0.7, Color = Color3.fromRGB(255, 160, 80), Shadows = false })
	end
	return m
end

function Props.Candelabra(parent, cf: CFrame, opts)
	local m = Build.Model(parent, "Candelabra")
	Cyl(m, 0.7, 0.15, at(cf, 0, 0.075, 0), C.Gold, M.Metal, { decor = true })
	Cyl(m, 0.18, 1.3, at(cf, 0, 0.75, 0), C.Gold, M.Metal, { decor = true })
	D(m, Vector3.new(1.6, 0.12, 0.12), at(cf, 0, 1.4, 0), C.Gold, M.Metal)
	for i, x in { -0.75, 0, 0.75 } do
		Props.Candle(m, at(cf, x, 1.46, 0).Position, { height = 0.6, light = i == 2 and (opts == nil or opts.light ~= false) })
	end
	return m
end

function Props.DeskLamp(parent, cf: CFrame, zone: string?)
	local m = Build.Model(parent, "DeskLamp")
	Cyl(m, 0.6, 0.12, at(cf, 0, 0.06, 0), C.Gold, M.Metal, { decor = true })
	Cyl(m, 0.12, 1.2, at(cf, 0, 0.7, 0), C.Gold, M.Metal, { decor = true })
	local shade = Cyl(m, 1, 0.6, at(cf, 0, 1.4, 0), Color3.fromRGB(120, 90, 60), M.Fabric, { decor = true })
	if zone then
		Build.Light(shade, "PointLight", { Range = 10, Brightness = 0.7, Color = C.Warm, Shadows = false }, zone)
	end
	return m
end

----------------------------------------------------------------------------------------
-- Bedroom furniture
----------------------------------------------------------------------------------------

-- Bed with its headboard at local +Z. Returns the model; contains HideSpot/ExitPoint for hiding.
function Props.Bed(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Bed")
	local w = opts.single and 4.5 or 7
	local l = 9
	local frameColor = opts.frame or C.Walnut
	local sheet = opts.sheet or C.Bone
	local blanket = opts.blanket or C.Burgundy
	-- legs + frame (raised so a player can hide underneath)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(0.5, 2.6, 0.5), at(cf, sx * (w / 2 - 0.3), 1.3, sz * (l / 2 - 0.3)), frameColor, M.Wood)
		end
	end
	P(m, Vector3.new(w, 0.5, l), at(cf, 0, 2.85, 0), frameColor, M.Wood, { name = "Frame" })
	D(m, Vector3.new(w - 0.3, 0.9, l - 0.4), at(cf, 0, 3.55, 0.1), sheet, M.Fabric)
	local tilt = opts.messy and CFrame.Angles(0, math.rad(8), math.rad(3)) or CFrame.new()
	D(m, Vector3.new(w + 0.1, 0.25, l * 0.62), at(cf, 0, 4.05, -l * 0.17) * tilt, blanket, M.Fabric)
	if not opts.messy then
		D(m, Vector3.new(w + 0.12, 1.5, 0.15), at(cf, 0, 3.4, -l / 2 - 0.05), blanket, M.Fabric)
	end
	for _, x in (opts.single and { 0 } or { -w / 4, w / 4 }) do
		D(m, Vector3.new(w / (opts.single and 1.6 or 2.6), 0.6, 1.4), at(cf, x, 4.25, l / 2 - 1.2) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(230, 222, 205), M.Fabric)
	end
	-- headboard
	P(m, Vector3.new(w + 0.4, 6, 0.5), at(cf, 0, 3, l / 2 + 0.2), frameColor, M.Wood)
	D(m, Vector3.new(w - 0.6, 3, 0.2), at(cf, 0, 4.4, l / 2 - 0.1), opts.panel or C.DeepBurgundy, M.Fabric)
	D(m, Vector3.new(w + 0.6, 0.3, 0.7), at(cf, 0, 6.1, l / 2 + 0.2), C.Gold, M.Metal)
	-- hiding helpers
	local hide = P(m, Vector3.new(1, 1, 1), at(cf, 0, 3, 0), Color3.new(), M.SmoothPlastic, { transparency = 1, collide = false, name = "HideSpot" })
	hide.CanQuery = false
	local exit = P(m, Vector3.new(1, 1, 1), at(cf, 0, 3, -l / 2 - 2.5) * CFrame.Angles(0, math.pi, 0), Color3.new(), M.SmoothPlastic, { transparency = 1, collide = false, name = "ExitPoint" })
	exit.CanQuery = false
	local view = P(m, Vector3.new(0.5, 0.5, 0.5), at(cf, 0, 1.2, -l / 2 + 0.3), Color3.new(), M.SmoothPlastic, { transparency = 1, collide = false, name = "ViewPoint" })
	view.CanQuery = false
	-- the dark gap under the bed
	D(m, Vector3.new(w - 0.6, 0.05, l - 0.6), at(cf, 0, 0.03, 0), Color3.fromRGB(10, 8, 8), M.SmoothPlastic, { transparency = 0.3 })
	m:SetAttribute("HideKind", "bed")
	return m
end

function Props.Nightstand(parent, cf: CFrame, zone: string?)
	local m = Build.Model(parent, "Nightstand")
	P(m, Vector3.new(2, 2.4, 1.8), at(cf, 0, 1.2, 0), C.Walnut, M.Wood)
	D(m, Vector3.new(1.6, 0.6, 0.1), at(cf, 0, 1.6, -0.92), C.DarkBrown, M.Wood)
	D(m, Vector3.new(0.3, 0.12, 0.12), at(cf, 0, 1.6, -1), C.Gold, M.Metal)
	Props.DeskLamp(m, at(cf, 0.2, 2.4, 0.2), zone)
	return m
end

-- Wardrobe; doubles as a hiding spot.
function Props.Wardrobe(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, opts.name or "Wardrobe")
	local w, h, d = opts.width or 4.6, opts.height or 8.4, 2.8
	local wood = opts.color or C.DarkBrown
	local mat = opts.material or M.Wood
	P(m, Vector3.new(w, h, 0.2), at(cf, 0, h / 2, d / 2 - 0.1), wood, mat) -- back
	P(m, Vector3.new(0.2, h, d), at(cf, -w / 2 + 0.1, h / 2, 0), wood, mat)
	P(m, Vector3.new(0.2, h, d), at(cf, w / 2 - 0.1, h / 2, 0), wood, mat)
	P(m, Vector3.new(w, 0.3, d), at(cf, 0, h - 0.15, 0), wood, mat)
	P(m, Vector3.new(w, 0.4, d), at(cf, 0, 0.2, 0), wood, mat)
	D(m, Vector3.new(w + 0.3, 0.3, d + 0.3), at(cf, 0, h + 0.15, 0), opts.trim or C.DimGold, M.Wood)
	D(m, Vector3.new(w - 0.4, h - 0.8, 0.1), at(cf, 0, h / 2, d / 2 - 0.25), Color3.fromRGB(8, 6, 6), M.SmoothPlastic)
	-- doors (each a separate part so the hiding system can swing them)
	for i, sx in { -1, 1 } do
		local door = P(m, Vector3.new(w / 2 - 0.15, h - 0.8, 0.2), at(cf, sx * (w / 4), h / 2, -d / 2 + 0.1), wood, mat, { name = i == 1 and "DoorL" or "DoorR" })
		door:SetAttribute("ClosedCF", door.CFrame)
		local panel = D(m, Vector3.new(w / 2 - 0.8, h - 2.4, 0.05), door.CFrame * CFrame.new(0, 0, -0.12), opts.panel or C.Walnut, mat, { name = "Panel" .. i })
		panel:SetAttribute("Door", door.Name)
		local knob = Ball(m, 0.25, (door.CFrame * CFrame.new(-sx * (w / 4 - 0.45), 0, -0.2)).Position, C.Gold, M.Metal, { decor = true, name = "Knob" .. i })
		knob:SetAttribute("Door", door.Name)
	end
	local hide = P(m, Vector3.new(1, 1, 1), at(cf, 0, 3, 0.1), Color3.new(), M.SmoothPlastic, { transparency = 1, collide = false, name = "HideSpot" })
	hide.CanQuery = false
	local exit = P(m, Vector3.new(1, 1, 1), at(cf, 0, 3, -d / 2 - 2.6) * CFrame.Angles(0, math.pi, 0), Color3.new(), M.SmoothPlastic, { transparency = 1, collide = false, name = "ExitPoint" })
	exit.CanQuery = false
	local view = P(m, Vector3.new(0.5, 0.5, 0.5), at(cf, 0, 5.2, -d / 2 + 0.6), Color3.new(), M.SmoothPlastic, { transparency = 1, collide = false, name = "ViewPoint" })
	view.CanQuery = false
	m:SetAttribute("HideKind", "wardrobe")
	return m
end

function Props.Locker(parent, cf: CFrame)
	return Props.Wardrobe(parent, cf, { name = "Locker", width = 3.2, height = 7.6, color = Color3.fromRGB(64, 72, 70), material = M.Metal, trim = C.Charcoal, panel = Color3.fromRGB(56, 62, 60) })
end

function Props.Desk(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Desk")
	local w = opts.width or 5
	local color = opts.color or C.Walnut
	P(m, Vector3.new(w, 0.3, 2.6), at(cf, 0, 3, 0), color, M.Wood)
	P(m, Vector3.new(1.6, 2.85, 2.4), at(cf, -w / 2 + 0.85, 1.425, 0), color, M.Wood)
	P(m, Vector3.new(0.3, 2.85, 2.4), at(cf, w / 2 - 0.2, 1.425, 0), color, M.Wood)
	for i = 0, 2 do
		D(m, Vector3.new(1.4, 0.75, 0.1), at(cf, -w / 2 + 0.85, 0.6 + i * 0.9, 1.25), C.DarkBrown, M.Wood)
		D(m, Vector3.new(0.3, 0.1, 0.1), at(cf, -w / 2 + 0.85, 0.6 + i * 0.9, 1.32), C.Gold, M.Metal)
	end
	if opts.chair ~= false then
		Props.Chair(parent, at(cf, 0.3, 0, 2.1))
	end
	if opts.lamp then
		Props.DeskLamp(m, at(cf, w / 2 - 0.7, 3.15, -0.6), opts.zone)
	end
	if opts.papers ~= false then
		for i = 1, 3 do
			D(m, Vector3.new(0.85, 0.02, 1.1), at(cf, -0.6 + i * 0.4, 3.16 + i * 0.01, -0.1) * CFrame.Angles(0, math.rad(i * 17), 0), C.Paper, M.SmoothPlastic)
		end
	end
	return m
end

function Props.Chair(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Chair")
	local base = opts.fallen and cf * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, -0.9, 0) or cf
	local wood = opts.color or C.Walnut
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(0.25, 1.8, 0.25), at(base, sx * 0.8, 0.9, sz * 0.8), wood, M.Wood, { collide = false })
		end
	end
	P(m, Vector3.new(2, 0.35, 2), at(base, 0, 1.9, 0), opts.seat or C.Burgundy, M.Fabric)
	P(m, Vector3.new(2, 2.4, 0.25), at(base, 0, 3.2, 0.9), wood, M.Wood)
	D(m, Vector3.new(1.5, 1.6, 0.1), at(base, 0, 3.3, 0.76), opts.seat or C.Burgundy, M.Fabric)
	return m
end

function Props.Armchair(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Armchair")
	local fabric = opts.color or C.Burgundy
	P(m, Vector3.new(3.2, 1.6, 3), at(cf, 0, 0.8, 0), C.DarkBrown, M.Wood)
	P(m, Vector3.new(2.6, 0.7, 2.6), at(cf, 0, 1.95, -0.1), fabric, M.Fabric)
	P(m, Vector3.new(3.2, 3, 0.7), at(cf, 0, 3, 1.15), fabric, M.Fabric)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.5, 1.4, 3), at(cf, sx * 1.45, 2.3, 0), fabric, M.Fabric)
		D(m, Vector3.new(0.6, 0.2, 3.1), at(cf, sx * 1.45, 3.05, 0), C.DarkBrown, M.Wood)
	end
	return m
end

function Props.Sofa(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Sofa")
	local w = opts.width or 8
	local fabric = opts.color or C.Burgundy
	P(m, Vector3.new(w, 1.6, 3.2), at(cf, 0, 0.8, 0), C.DarkBrown, M.Wood)
	for i = 0, 2 do
		D(m, Vector3.new(w / 3 - 0.2, 0.7, 2.7), at(cf, -w / 3 + i * w / 3, 1.95, -0.15), fabric, M.Fabric)
	end
	P(m, Vector3.new(w, 3, 0.8), at(cf, 0, 3, 1.2), fabric, M.Fabric)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.7, 1.6, 3.2), at(cf, sx * (w / 2 - 0.35), 2.4, 0), fabric, M.Fabric)
	end
	D(m, Vector3.new(w + 0.1, 0.25, 0.9), at(cf, 0, 4.55, 1.2), C.Gold, M.Wood)
	if opts.torn then
		D(m, Vector3.new(1.4, 0.75, 1.2), at(cf, w / 4, 2, -0.3), Color3.fromRGB(190, 175, 140), M.Fabric)
	end
	return m
end

function Props.CoffeeTable(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "CoffeeTable")
	local w = opts.width or 4
	P(m, Vector3.new(w, 0.3, 2.4), at(cf, 0, 1.6, 0), C.Marble, M.Marble)
	D(m, Vector3.new(w + 0.1, 0.12, 2.5), at(cf, 0, 1.4, 0), C.Gold, M.Metal)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(0.25, 1.45, 0.25), at(cf, sx * (w / 2 - 0.3), 0.72, sz * 0.9), C.Gold, M.Metal, { collide = false })
		end
	end
	return m
end

function Props.Rug(parent, cf: CFrame, w: number, l: number, color: Color3?, border: Color3?)
	local m = Build.Model(parent, "Rug")
	D(m, Vector3.new(w, 0.06, l), at(cf, 0, 0.03, 0), border or C.Gold, M.Fabric)
	D(m, Vector3.new(w - 0.8, 0.07, l - 0.8), at(cf, 0, 0.04, 0), color or C.Burgundy, M.Fabric)
	return m
end

function Props.Suitcase(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Suitcase")
	local color = opts.color or Color3.fromRGB(96, 62, 40)
	local base = opts.lying and cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(0, -0.6, 0) or cf
	P(m, Vector3.new(2.6, 1.9, 0.9), at(base, 0, 0.95, 0), color, M.Leather)
	D(m, Vector3.new(2.7, 0.15, 0.95), at(base, 0, 1.4, 0), C.DarkBrown, M.Leather)
	D(m, Vector3.new(0.9, 0.2, 0.25), at(base, 0, 2, 0), C.DarkBrown, M.Leather)
	D(m, Vector3.new(0.2, 0.2, 0.92), at(base, -0.9, 1.65, 0), C.Gold, M.Metal)
	D(m, Vector3.new(0.2, 0.2, 0.92), at(base, 0.9, 1.65, 0), C.Gold, M.Metal)
	return m
end

function Props.Plant(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "DeadPlant")
	Cyl(m, 1.6, 1.8, at(cf, 0, 0.9, 0), opts.pot or C.Marble, M.Marble)
	D(m, Vector3.new(1.4, 0.1, 1.4), at(cf, 0, 1.82, 0), Color3.fromRGB(40, 30, 22), M.Ground)
	local rng = Build.Rng(opts.seed or 7)
	for i = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local lean = rng:NextNumber(10, 35)
		local h = rng:NextNumber(1.8, 3.2)
		D(m, Vector3.new(0.15, h, 0.15), at(cf, 0, 1.8, 0) * CFrame.Angles(0, a, math.rad(lean)) * CFrame.new(0, h / 2, 0), Color3.fromRGB(70, 56, 36), M.Wood)
		if i % 2 == 0 then
			D(m, Vector3.new(0.6, 0.06, 0.3), at(cf, 0, 1.8, 0) * CFrame.Angles(0, a, math.rad(lean)) * CFrame.new(0.2, h, 0), Color3.fromRGB(80, 70, 40), M.Fabric)
		end
	end
	return m
end

----------------------------------------------------------------------------------------
-- Wall decor
----------------------------------------------------------------------------------------

-- Procedural painting drawn with SurfaceGui frames (no image assets needed).
-- `cf` on the wall surface facing into the room. kind: "portrait" | "hotel" | "eyes" | "symbol"
function Props.Painting(parent, cf: CFrame, w: number, h: number, kind: string, seed: number?)
	local m = Build.Model(parent, "Painting")
	D(m, Vector3.new(w + 0.6, h + 0.6, 0.25), cf * CFrame.new(0, 0, -0.13), C.Gold, M.Foil, { name = "Frame" })
	local canvas = D(m, Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.3), Color3.fromRGB(24, 18, 16), M.SmoothPlastic, { name = "Canvas" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = canvas
	local function frame(props)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		for k, v in props do
			if k ~= "corner" then
				f[k] = v
			end
		end
		if props.corner then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(props.corner, 0)
			c.Parent = f
		end
		f.Parent = gui
		return f
	end
	local bg = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(34, 24, 22) })
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(60, 36, 30), Color3.fromRGB(14, 10, 12))
	grad.Rotation = 90
	grad.Parent = bg
	local rng = Build.Rng(seed or 3)
	if kind == "portrait" or kind == "eyes" then
		frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1.02), Size = UDim2.fromScale(0.85, 0.42), BackgroundColor3 = Color3.fromRGB(20, 14, 14), corner = 0.45 })
		frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.42, 0.34), BackgroundColor3 = Color3.fromRGB(150 + rng:NextInteger(0, 40), 130, 110), corner = 0.5 })
		if kind == "eyes" then
			for _, x in { 0.42, 0.58 } do
				frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.4), Size = UDim2.fromScale(0.08, 0.05), BackgroundColor3 = Color3.fromRGB(10, 0, 0), corner = 0.5 })
			end
			frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.42, 0.43), Size = UDim2.fromScale(0.02, 0.2), BackgroundColor3 = C.Blood })
		else
			frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.3, 0.06), BackgroundColor3 = Color3.fromRGB(10, 8, 8), BackgroundTransparency = 0.2 })
		end
	elseif kind == "hotel" then
		frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.22), Size = UDim2.fromScale(0.14, 0.14), BackgroundColor3 = Color3.fromRGB(220, 220, 200), corner = 0.5 })
		frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.45, 0.95), Size = UDim2.fromScale(0.6, 0.55), BackgroundColor3 = Color3.fromRGB(16, 12, 14) })
		frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.45, 0.42), Size = UDim2.fromScale(0.2, 0.1), BackgroundColor3 = Color3.fromRGB(16, 12, 14) })
		for i = 0, 5 do
			frame({ Position = UDim2.fromScale(0.2 + (i % 3) * 0.18, 0.5 + math.floor(i / 3) * 0.18), Size = UDim2.fromScale(0.07, 0.08), BackgroundColor3 = i == 4 and C.Warm or Color3.fromRGB(40, 36, 30) })
		end
	else
		frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), BackgroundTransparency = 1 })
		local stroke = Instance.new("UIStroke")
		stroke.Color = C.Blood
		stroke.Thickness = 6
		local ring = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.45), BackgroundTransparency = 1, corner = 0.5 })
		stroke.Parent = ring
		for i = 0, 2 do
			frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.025), BackgroundColor3 = C.Blood, Rotation = i * 60 })
		end
	end
	Build.Tag(m, "Painting")
	return m
end

function Props.Mirror(parent, cf: CFrame, w: number, h: number, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Mirror")
	D(m, Vector3.new(w + 0.5, h + 0.5, 0.25), cf * CFrame.new(0, 0, -0.13), opts.frame or C.Gold, M.Foil, { name = "Frame" })
	local glass = D(m, Vector3.new(w, h, 0.08), cf * CFrame.new(0, 0, -0.3), Color3.fromRGB(150, 160, 170), M.Glass, { reflect = 0.55, name = "Glass", transparency = 0.05 })
	if opts.broken then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = glass
		local rng = Build.Rng(opts.seed or 11)
		for i = 1, 9 do
			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.Position = UDim2.fromScale(0.55, 0.4)
			line.Size = UDim2.new(rng:NextNumber(0.3, 0.7), 0, 0, 2)
			line.Rotation = i * 40 + rng:NextInteger(-15, 15)
			line.BackgroundColor3 = Color3.fromRGB(230, 235, 240)
			line.BorderSizePixel = 0
			line.Parent = gui
		end
	end
	if opts.text then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = glass
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.9, 0.5)
		label.Position = UDim2.fromScale(0.05, 0.25)
		label.Font = Enum.Font.Creepster
		label.TextScaled = true
		label.TextColor3 = C.Blood
		label.Text = opts.text
		label.Rotation = -6
		label.Parent = gui
	end
	return m, glass
end

function Props.WallText(parent, cf: CFrame, w: number, h: number, text: string, opts)
	opts = opts or {}
	return Build.Text(parent, Vector3.new(w, h, 0.05), cf * CFrame.new(0, 0, -0.06), text, {
		bgTransparency = 1,
		font = opts.font or Enum.Font.Creepster,
		color = opts.color or C.Blood,
		rotation = opts.rotation or -4,
		ppu = 24,
		name = "WallWriting",
	})
end

function Props.Window(parent, cf: CFrame, w: number, h: number, opts)
	opts = opts or {}
	-- cf: centre of the opening on the interior face, LookVector into the room
	local m = Build.Model(parent, "Window")
	if not opts.broken then
		D(m, Vector3.new(w, h, 0.15), cf * CFrame.new(0, 0, 0.45), Color3.fromRGB(70, 90, 120), M.Glass, { transparency = 0.55, reflect = 0.15 })
	else
		D(m, Vector3.new(w * 0.4, h * 0.3, 0.15), cf * CFrame.new(-w * 0.3, -h * 0.35, 0.45) * CFrame.Angles(0, 0, 0.3), Color3.fromRGB(70, 90, 120), M.Glass, { transparency = 0.5 })
	end
	D(m, Vector3.new(0.25, h, 0.3), cf * CFrame.new(0, 0, 0.45), C.DarkBrown, M.Wood)
	D(m, Vector3.new(w, 0.25, 0.3), cf * CFrame.new(0, 0, 0.45), C.DarkBrown, M.Wood)
	D(m, Vector3.new(w + 0.6, 0.3, 0.7), cf * CFrame.new(0, -h / 2 - 0.15, -0.1), C.DarkBrown, M.Wood)
	if opts.curtains ~= false then
		local color = opts.curtain or C.Burgundy
		for _, sx in { -1, 1 } do
			D(m, Vector3.new(w * 0.32, h + 1.6, 0.25), cf * CFrame.new(sx * (w / 2 - w * 0.08), 0.3, -0.35), color, M.Fabric)
		end
		D(m, Vector3.new(w + 1.4, 0.5, 0.5), cf * CFrame.new(0, h / 2 + 1, -0.35), C.Gold, M.Metal)
	end
	return m
end

function Props.Shelf(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, opts.name or "Shelf")
	local w, h, d = opts.width or 6, opts.height or 9, opts.depth or 1.8
	local wood = opts.color or C.DarkBrown
	local mat = opts.material or M.Wood
	P(m, Vector3.new(w, h, 0.2), at(cf, 0, h / 2, d / 2 - 0.1), wood, mat)
	P(m, Vector3.new(0.25, h, d), at(cf, -w / 2, h / 2, 0), wood, mat)
	P(m, Vector3.new(0.25, h, d), at(cf, w / 2, h / 2, 0), wood, mat)
	local rows = opts.rows or 4
	local rng = Build.Rng(opts.seed or 5)
	for r = 0, rows do
		local y = 0.2 + r * (h - 0.4) / rows
		P(m, Vector3.new(w, 0.2, d), at(cf, 0, y, 0), wood, mat)
		if r < rows and opts.fill ~= false then
			local x = -w / 2 + 0.3
			while x < w / 2 - 0.6 do
				local kind = opts.fill or "books"
				if kind == "books" then
					local bw = rng:NextNumber(0.25, 0.5)
					local bh = rng:NextNumber(1, (h - 0.4) / rows - 0.3)
					local hue = rng:NextInteger(1, 5)
					local colors = { C.Burgundy, C.DarkBrown, Color3.fromRGB(30, 50, 40), Color3.fromRGB(28, 32, 58), C.DimGold }
					if rng:NextNumber() < 0.85 then
						D(m, Vector3.new(bw, bh, d - 0.5), at(cf, x + bw / 2, y + 0.1 + bh / 2, 0) * CFrame.Angles(0, 0, rng:NextNumber() < 0.1 and 0.25 or 0), colors[hue], M.Leather)
					end
					x += bw + 0.03
				elseif kind == "boxes" then
					local bw = rng:NextNumber(1, 1.8)
					if rng:NextNumber() < 0.75 then
						D(m, Vector3.new(bw, rng:NextNumber(0.8, 1.6), d - 0.3), at(cf, x + bw / 2, y + 0.9, 0), Color3.fromRGB(120, 96, 66), M.Cardboard)
					end
					x += bw + 0.2
				elseif kind == "linen" then
					D(m, Vector3.new(1.4, 0.9, d - 0.4), at(cf, x + 0.7, y + 0.55, 0), Color3.fromRGB(220, 214, 200), M.Fabric)
					x += 1.6
				elseif kind == "bottles" then
					if rng:NextNumber() < 0.8 then
						local col = ({ Color3.fromRGB(40, 70, 40), Color3.fromRGB(90, 40, 20), Color3.fromRGB(150, 140, 120) })[rng:NextInteger(1, 3)]
						Cyl(m, 0.35, 1.1, at(cf, x + 0.2, y + 0.65, 0), col, M.Glass, { decor = true, transparency = 0.25 })
					end
					x += 0.55
				else
					x = w
				end
			end
		end
	end
	return m
end

function Props.DiningTable(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "DiningTable")
	local w, l = opts.width or 4, opts.length or 6
	P(m, Vector3.new(w, 0.3, l), at(cf, 0, 3, 0), C.Walnut, M.Wood)
	D(m, Vector3.new(w + 0.3, 1.8, l + 0.3), at(cf, 0, 2.3, 0), opts.cloth or C.Bone, M.Fabric, { transparency = 0 })
	D(m, Vector3.new(w + 0.32, 0.1, l + 0.32), at(cf, 0, 3.2, 0), opts.cloth or C.Bone, M.Fabric)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(0.35, 2.85, 0.35), at(cf, sx * (w / 2 - 0.4), 1.425, sz * (l / 2 - 0.4)), C.Walnut, M.Wood, { collide = false })
		end
	end
	local seats = opts.seats or 2
	for i = 1, seats do
		local z = -l / 2 + (i - 0.5) * l / seats
		for _, sx in { -1, 1 } do
			local fallen = opts.fallenChair == i and sx == 1
			Props.Chair(parent, at(cf, sx * (w / 2 + 1.1), 0, z) * CFrame.Angles(0, sx * math.rad(90), 0), { fallen = fallen })
			D(m, Vector3.new(1, 0.05, 1), at(cf, sx * (w / 2 - 0.8), 3.24, z), Color3.fromRGB(235, 232, 225), M.SmoothPlastic)
			D(m, Vector3.new(0.08, 0.04, 0.9), at(cf, sx * (w / 2 - 0.15), 3.24, z), Color3.fromRGB(200, 200, 205), M.Metal)
		end
	end
	if opts.candles ~= false then
		Props.Candelabra(m, at(cf, 0, 3.15, 0), { light = opts.candleLight })
	end
	if opts.blood then
		D(m, Vector3.new(1.6, 0.03, 2), at(cf, 0.6, 3.27, 1), C.Blood, M.SmoothPlastic, { transparency = 0.1 })
	end
	return m
end

function Props.Cloche(parent, cf: CFrame)
	local m = Build.Model(parent, "Cloche")
	Cyl(m, 1.6, 0.08, at(cf, 0, 0.04, 0), Color3.fromRGB(205, 205, 210), M.Metal, { decor = true })
	Ball(m, 1.3, at(cf, 0.9, 0.55, 0.3).Position, Color3.fromRGB(205, 205, 210), M.Metal, { decor = true, name = "Dome" })
	return m
end

function Props.Fireplace(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Fireplace")
	P(m, Vector3.new(8, 7, 2), at(cf, 0, 3.5, 0.6), C.Marble, M.Marble)
	D(m, Vector3.new(5, 4, 0.4), at(cf, 0, 2, -0.3), Color3.fromRGB(8, 6, 6), M.Slate)
	D(m, Vector3.new(9, 0.5, 2.6), at(cf, 0, 7.2, 0.4), C.Gold, M.Marble)
	D(m, Vector3.new(4, 0.5, 1.2), at(cf, 0, 0.25, -0.8), Color3.fromRGB(40, 30, 26), M.Slate)
	local embers = D(m, Vector3.new(3, 0.4, 0.8), at(cf, 0, 0.6, -0.2), Color3.fromRGB(255, 90, 30), M.Neon, { name = "Embers" })
	if opts.fire ~= false then
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 4
		fire.Color = Color3.fromRGB(255, 120, 40)
		fire.SecondaryColor = Color3.fromRGB(120, 20, 10)
		fire.Parent = embers
		Build.Light(embers, "PointLight", { Range = 18, Brightness = 1.4, Color = Color3.fromRGB(255, 130, 60), Shadows = true })
	end
	return m
end

function Props.Piano(parent, cf: CFrame)
	local m = Build.Model(parent, "Piano")
	P(m, Vector3.new(6, 1.6, 7), at(cf, 0, 3.4, 0.8), C.Black, M.SmoothPlastic, { reflect = 0.1 })
	P(m, Vector3.new(6, 0.3, 1.4), at(cf, 0, 2.8, -3.2), C.Black, M.SmoothPlastic)
	D(m, Vector3.new(5.6, 0.12, 0.9), at(cf, 0, 3, -3.2), C.Bone, M.SmoothPlastic)
	for i = 0, 17 do
		D(m, Vector3.new(0.14, 0.14, 0.5), at(cf, -2.6 + i * 0.31, 3.1, -3), C.Black, M.SmoothPlastic)
	end
	D(m, Vector3.new(5.6, 0.2, 6), at(cf, 0, 5.5, 1.6) * CFrame.Angles(math.rad(-35), 0, 0), C.Black, M.SmoothPlastic)
	for _, x in { -2.5, 2.5 } do
		P(m, Vector3.new(0.5, 2.6, 0.5), at(cf, x, 1.3, -1.5), C.Black, M.SmoothPlastic)
	end
	P(m, Vector3.new(0.5, 2.6, 0.5), at(cf, 0, 1.3, 3.5), C.Black, M.SmoothPlastic)
	P(m, Vector3.new(3.5, 1.9, 1.4), at(cf, 0, 0.95, -5), C.Black, M.Leather)
	return m
end

function Props.GrandfatherClock(parent, cf: CFrame)
	local m = Build.Model(parent, "Clock")
	P(m, Vector3.new(2.2, 8, 1.4), at(cf, 0, 4, 0), C.DarkBrown, M.Wood)
	D(m, Vector3.new(2.4, 0.6, 1.6), at(cf, 0, 8.2, 0), C.Gold, M.Wood)
	local face = Cyl(m, 1.6, 0.1, at(cf, 0, 6.6, -0.72) * CFrame.Angles(math.rad(90), 0, 0), C.Bone, M.SmoothPlastic, { decor = true })
	face.Name = "Face"
	D(m, Vector3.new(0.08, 0.6, 0.05), at(cf, 0, 6.85, -0.8), C.Black, M.Metal)
	D(m, Vector3.new(0.08, 0.5, 0.05), at(cf, 0.18, 6.55, -0.8) * CFrame.Angles(0, 0, math.rad(-60)), C.Black, M.Metal)
	D(m, Vector3.new(1.2, 3.6, 0.05), at(cf, 0, 3.2, -0.72), Color3.fromRGB(20, 16, 14), M.Glass, { transparency = 0.3 })
	Ball(m, 0.7, at(cf, 0, 2.2, -0.5).Position, C.Gold, M.Metal, { decor = true, name = "Pendulum" })
	return m
end

function Props.Column(parent, pos: Vector3, height: number, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Column")
	Cyl(m, opts.d or 2.4, height, pos + Vector3.new(0, height / 2, 0), opts.color or C.Marble, M.Marble)
	P(m, Vector3.new(3.2, 1, 3.2), CFrame.new(pos + Vector3.new(0, 0.5, 0)), C.Gold, M.Marble)
	P(m, Vector3.new(3.2, 1, 3.2), CFrame.new(pos + Vector3.new(0, height - 0.5, 0)), C.Gold, M.Marble)
	return m
end

function Props.BloodStain(parent, pos: Vector3, size: number, seed: number?)
	local m = Build.Model(parent, "Blood")
	local rng = Build.Rng(seed or 1)
	for i = 1, 5 do
		local d = size * rng:NextNumber(0.35, 1)
		local off = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.4
		Cyl(m, d, 0.04 + i * 0.002, pos + off + Vector3.new(0, 0.03 + i * 0.002, 0), i == 1 and C.DryBlood or C.Blood, M.SmoothPlastic, { decor = true, transparency = 0.08 })
	end
	return m
end

-- A smeared trail between two floor points.
function Props.DragMarks(parent, a: Vector3, b: Vector3)
	local m = Build.Model(parent, "DragMarks")
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	for _, off in { -0.5, 0.5 } do
		local cf = CFrame.lookAt(mid, b) * CFrame.new(off, 0.04, 0)
		D(m, Vector3.new(0.35, 0.04, len), cf, C.DryBlood, M.SmoothPlastic, { transparency = 0.2 })
	end
	return m
end

function Props.HandPrint(parent, cf: CFrame)
	local m = Build.Model(parent, "HandPrint")
	D(m, Vector3.new(0.7, 0.8, 0.03), cf * CFrame.new(0, 0, -0.03), C.Blood, M.SmoothPlastic)
	for i = 0, 3 do
		D(m, Vector3.new(0.12, 0.5, 0.03), cf * CFrame.new(-0.3 + i * 0.2, 0.6, -0.03) * CFrame.Angles(0, 0, math.rad(-12 + i * 8)), C.Blood, M.SmoothPlastic)
	end
	D(m, Vector3.new(0.12, 0.4, 0.03), cf * CFrame.new(0.45, 0.05, -0.03) * CFrame.Angles(0, 0, math.rad(-50)), C.Blood, M.SmoothPlastic)
	return m
end

function Props.Debris(parent, pos: Vector3, amount: number, seed: number?)
	local m = Build.Model(parent, "Debris")
	local rng = Build.Rng(seed or 9)
	for _ = 1, amount do
		local s = Vector3.new(rng:NextNumber(0.3, 1.6), rng:NextNumber(0.2, 0.7), rng:NextNumber(0.3, 1.4))
		local off = Vector3.new(rng:NextNumber(-3, 3), s.Y / 2, rng:NextNumber(-3, 3))
		local col = rng:NextNumber() < 0.5 and C.Plaster or Color3.fromRGB(110, 100, 90)
		D(m, s, CFrame.new(pos + off) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), col, M.Concrete)
	end
	for _ = 1, math.floor(amount / 3) do
		local len = rng:NextNumber(2, 5)
		D(m, Vector3.new(0.35, 0.25, len), CFrame.new(pos + Vector3.new(rng:NextNumber(-3, 3), 0.15, rng:NextNumber(-3, 3))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.1), C.DarkBrown, M.WoodPlanks)
	end
	return m
end

function Props.Crate(parent, cf: CFrame, size: number?)
	local s = size or 3
	local m = Build.Model(parent, "Crate")
	P(m, Vector3.new(s, s, s), at(cf, 0, s / 2, 0), Color3.fromRGB(110, 84, 56), M.WoodPlanks)
	for _, y in { 0.15, s - 0.15 } do
		D(m, Vector3.new(s + 0.1, 0.3, s + 0.1), at(cf, 0, y, 0), Color3.fromRGB(80, 60, 40), M.Wood)
	end
	return m
end

function Props.Barrel(parent, cf: CFrame, color: Color3?)
	local m = Build.Model(parent, "Barrel")
	Cyl(m, 2.4, 3.4, at(cf, 0, 1.7, 0), color or C.Rust, M.CorrodedMetal)
	for _, y in { 0.6, 2.8 } do
		Cyl(m, 2.5, 0.2, at(cf, 0, y, 0), C.Charcoal, M.Metal, { decor = true })
	end
	return m
end

function Props.Pipe(parent, a: Vector3, b: Vector3, d: number?, color: Color3?)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	return D(parent, Vector3.new(len, d or 0.8, d or 0.8), cf, color or C.Rust, M.CorrodedMetal, { shape = Enum.PartType.Cylinder })
end

function Props.Phone(parent, cf: CFrame)
	local m = Build.Model(parent, "Phone")
	local base = P(m, Vector3.new(1.2, 0.5, 1.4), at(cf, 0, 0.25, 0), C.Black, M.SmoothPlastic, { name = "Base", collide = false })
	Cyl(m, 0.8, 0.06, at(cf, 0, 0.53, -0.1), C.Bone, M.SmoothPlastic, { decor = true })
	D(m, Vector3.new(1.5, 0.3, 0.35), at(cf, 0, 0.7, 0.35), C.Black, M.SmoothPlastic, { name = "Handset" })
	Build.Tag(m, "Phone")
	return m, base
end

function Props.Bell(parent, cf: CFrame)
	local m = Build.Model(parent, "Bell")
	Cyl(m, 0.8, 0.1, at(cf, 0, 0.05, 0), C.Black, M.Wood, { decor = true })
	local dome = Ball(m, 0.7, at(cf, 0, 0.3, 0).Position, C.Gold, M.Metal, { decor = true, name = "Dome" })
	return m, dome
end

function Props.Monitor(parent, cf: CFrame, text: string)
	local m = Build.Model(parent, "Monitor")
	P(m, Vector3.new(2.2, 1.8, 1.8), at(cf, 0, 0.9, 0.2), Color3.fromRGB(60, 58, 52), M.SmoothPlastic, { collide = false })
	local screen = Build.Text(m, Vector3.new(1.8, 1.4, 0.05), at(cf, 0, 0.95, -0.72), text, {
		bg = Color3.fromRGB(10, 22, 16),
		color = Color3.fromRGB(120, 230, 150),
		font = Enum.Font.Code,
		brightness = 2,
		lightInfluence = 0,
		name = "Screen",
	})
	return m, screen
end

function Props.Toilet(parent, cf: CFrame)
	local m = Build.Model(parent, "Toilet")
	P(m, Vector3.new(1.6, 1.8, 2.2), at(cf, 0, 0.9, -0.2), C.Bone, M.SmoothPlastic)
	P(m, Vector3.new(1.8, 2.2, 0.8), at(cf, 0, 2.2, 0.9), C.Bone, M.SmoothPlastic)
	return m
end

function Props.Sink(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Sink")
	P(m, Vector3.new(3, 0.5, 2), at(cf, 0, 3, 0), C.Marble, M.Marble)
	P(m, Vector3.new(1, 3, 1), at(cf, 0, 1.5, 0.3), C.Marble, M.Marble)
	D(m, Vector3.new(1.8, 0.1, 1.2), at(cf, 0, 3.26, 0), opts.blood and C.Blood or Color3.fromRGB(180, 180, 185), M.SmoothPlastic)
	D(m, Vector3.new(0.2, 0.7, 0.2), at(cf, 0, 3.6, 0.7), C.Gold, M.Metal)
	return m
end

function Props.Bathtub(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "Bathtub")
	P(m, Vector3.new(3.6, 2.4, 7), at(cf, 0, 1.2, 0), C.Bone, M.SmoothPlastic)
	D(m, Vector3.new(3, 0.1, 6.2), at(cf, 0, 2.2, 0), opts.water or Color3.fromRGB(60, 28, 26), M.Glass, { transparency = 0.15 })
	return m
end

function Props.WashingMachine(parent, cf: CFrame)
	local m = Build.Model(parent, "Washer")
	P(m, Vector3.new(3, 3.6, 3), at(cf, 0, 1.8, 0), Color3.fromRGB(205, 200, 190), M.SmoothPlastic)
	Cyl(m, 1.9, 0.2, at(cf, 0, 1.7, -1.5) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(80, 80, 85), M.Metal, { decor = true })
	Cyl(m, 1.5, 0.22, at(cf, 0, 1.7, -1.52) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(40, 50, 60), M.Glass, { decor = true, transparency = 0.3 })
	D(m, Vector3.new(2.4, 0.4, 0.1), at(cf, 0, 3.2, -1.52), Color3.fromRGB(120, 120, 120), M.Metal)
	return m
end

function Props.HangingSheet(parent, cf: CFrame, w: number, h: number)
	local m = Build.Model(parent, "Sheet")
	D(m, Vector3.new(w + 1, 0.12, 0.12), cf, C.Charcoal, M.Metal)
	D(m, Vector3.new(w, h, 0.08), cf * CFrame.new(0, -h / 2, 0) * CFrame.Angles(math.rad(3), 0, 0), Color3.fromRGB(215, 210, 196), M.Fabric, { transparency = 0.1 })
	return m
end

function Props.Cart(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, opts.luggage and "LuggageCart" or "Cart")
	if opts.luggage then
		P(m, Vector3.new(3.2, 0.3, 5), at(cf, 0, 0.8, 0), C.Gold, M.Metal)
		for _, sx in { -1, 1 } do
			D(m, Vector3.new(0.2, 6, 0.2), at(cf, sx * 1.5, 3.9, 2.3), C.Gold, M.Metal)
		end
		D(m, Vector3.new(3.2, 0.2, 0.2), at(cf, 0, 6.9, 2.3), C.Gold, M.Metal)
		Props.Suitcase(m, at(cf, 0, 0.95, 0.5) * CFrame.Angles(0, math.rad(90), 0))
		Props.Suitcase(m, at(cf, 0.2, 2.85, 0.6) * CFrame.Angles(0, math.rad(84), 0), { color = C.Burgundy })
	else
		P(m, Vector3.new(2.6, 3, 4), at(cf, 0, 1.9, 0), Color3.fromRGB(90, 88, 80), M.Metal)
		D(m, Vector3.new(2.3, 0.8, 3.6), at(cf, 0, 3.6, 0), Color3.fromRGB(220, 214, 200), M.Fabric)
	end
	return m
end

function Props.Counter(parent, cf: CFrame, w: number, opts)
	opts = opts or {}
	local m = Build.Model(parent, opts.name or "Counter")
	P(m, Vector3.new(w, 3.4, 2.6), at(cf, 0, 1.7, 0), opts.color or C.Walnut, opts.material or M.Wood)
	P(m, Vector3.new(w + 0.4, 0.3, 3), at(cf, 0, 3.55, 0), opts.top or C.Marble, opts.topMaterial or M.Marble)
	if opts.trim ~= false then
		D(m, Vector3.new(w + 0.05, 0.3, 0.05), at(cf, 0, 3, -1.31), C.Gold, M.Metal)
		D(m, Vector3.new(w + 0.05, 0.3, 0.05), at(cf, 0, 0.4, -1.31), C.Gold, M.Metal)
		for x = -w / 2 + 1.5, w / 2 - 1, 3 do
			D(m, Vector3.new(2.2, 2, 0.05), at(cf, x, 1.7, -1.31), opts.panel or C.DarkBrown, M.Wood)
		end
	end
	return m
end

function Props.Stool(parent, cf: CFrame)
	local m = Build.Model(parent, "Stool")
	Cyl(m, 0.3, 2.8, at(cf, 0, 1.4, 0), C.Gold, M.Metal, { collide = false })
	Cyl(m, 1.4, 0.4, at(cf, 0, 2.9, 0), C.Burgundy, M.Leather)
	Cyl(m, 1.2, 0.1, at(cf, 0, 0.05, 0), C.Gold, M.Metal, { decor = true })
	return m
end

function Props.Stove(parent, cf: CFrame)
	local m = Build.Model(parent, "Stove")
	P(m, Vector3.new(4, 3.4, 2.8), at(cf, 0, 1.7, 0), Color3.fromRGB(60, 60, 62), M.Metal)
	for _, x in { -1, 1 } do
		for _, z in { -0.6, 0.6 } do
			Cyl(m, 1, 0.1, at(cf, x, 3.45, z), C.Black, M.Metal, { decor = true })
		end
	end
	D(m, Vector3.new(3.2, 1.6, 0.1), at(cf, 0, 1.4, -1.42), Color3.fromRGB(20, 20, 22), M.Glass, { transparency = 0.2 })
	return m
end

function Props.Boiler(parent, cf: CFrame)
	local m = Build.Model(parent, "Boiler")
	Cyl(m, 6, 9, at(cf, 0, 4.5, 0), C.Rust, M.CorrodedMetal)
	Cyl(m, 6.3, 0.4, at(cf, 0, 1, 0), C.Charcoal, M.Metal, { decor = true })
	Cyl(m, 6.3, 0.4, at(cf, 0, 8, 0), C.Charcoal, M.Metal, { decor = true })
	D(m, Vector3.new(1.6, 1.6, 0.3), at(cf, 0, 3, -3), C.Black, M.Metal)
	Cyl(m, 1, 0.2, at(cf, 1.6, 5.5, -3) * CFrame.Angles(math.rad(90), 0, 0), C.Bone, M.SmoothPlastic, { decor = true })
	Cyl(m, 1.4, 0.3, at(cf, -1.6, 5.5, -3) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(150, 20, 20), M.Metal, { decor = true })
	Props.Pipe(m, at(cf, 0, 9, 0).Position, at(cf, 0, 12.4, 0).Position, 1.2)
	local steam = D(m, Vector3.new(0.5, 0.5, 0.5), at(cf, 2.5, 7, -1.5), C.Rust, M.Metal, { transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(2, 4)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	emitter.Parent = steam
	Build.Tag(emitter, "AmbientParticles")
	return m
end

function Props.Generator(parent, cf: CFrame)
	local m = Build.Model(parent, "Generator")
	P(m, Vector3.new(10, 5, 5), at(cf, 0, 2.5, 0), Color3.fromRGB(60, 74, 58), M.Metal)
	Cyl(m, 4, 5.6, at(cf, -2.5, 4.4, 0) * CFrame.Angles(math.rad(90), 0, math.rad(90)), Color3.fromRGB(50, 62, 48), M.Metal)
	D(m, Vector3.new(3, 2, 0.3), at(cf, 2.8, 3.2, -2.6), C.Charcoal, M.Metal, { name = "Panel" })
	local light = D(m, Vector3.new(0.5, 0.5, 0.2), at(cf, 3.8, 3.8, -2.8), Color3.fromRGB(120, 10, 10), M.Neon, { name = "StatusLight" })
	Props.Pipe(m, at(cf, 4.5, 5, 1.5).Position, at(cf, 4.5, 12.4, 1.5).Position, 1)
	for i = 0, 4 do
		D(m, Vector3.new(0.15, 4, 4.8), at(cf, -1 + i * 0.6, 2.6, 0), C.Charcoal, M.Metal)
	end
	return m, light
end

function Props.SpecimenTank(parent, cf: CFrame, opts)
	opts = opts or {}
	local m = Build.Model(parent, "SpecimenTank")
	Cyl(m, 4, 1, at(cf, 0, 0.5, 0), C.Charcoal, M.Metal)
	Cyl(m, 4, 1, at(cf, 0, 9.5, 0), C.Charcoal, M.Metal)
	local liquid = Cyl(m, 3.4, 7.6, at(cf, 0, 5, 0), opts.liquid or Color3.fromRGB(60, 160, 120), M.Glass, { decor = true, transparency = 0.45 })
	Cyl(m, 3.7, 8, at(cf, 0, 5, 0), Color3.fromRGB(180, 210, 220), M.Glass, { transparency = 0.75 })
	if opts.figure ~= false then
		local dark = Color3.fromRGB(20, 22, 22)
		D(m, Vector3.new(1, 2.4, 0.6), at(cf, 0, 5.2, 0), dark, M.SmoothPlastic)
		Ball(m, 0.9, at(cf, 0, 6.9, 0).Position, dark, M.SmoothPlastic, { decor = true })
		for _, sx in { -1, 1 } do
			D(m, Vector3.new(0.35, 2.2, 0.35), at(cf, sx * 0.7, 5, 0) * CFrame.Angles(0, 0, sx * 0.2), dark, M.SmoothPlastic)
			D(m, Vector3.new(0.4, 2.4, 0.4), at(cf, sx * 0.3, 2.9, 0), dark, M.SmoothPlastic)
		end
	end
	Build.Light(liquid, "PointLight", { Range = 12, Brightness = 0.9, Color = opts.liquid or Color3.fromRGB(80, 220, 160), Shadows = false }, "B")
	return m
end

function Props.OperatingTable(parent, cf: CFrame)
	local m = Build.Model(parent, "OperatingTable")
	P(m, Vector3.new(3, 0.4, 7.5), at(cf, 0, 3.2, 0), Color3.fromRGB(160, 165, 170), M.Metal)
	Cyl(m, 0.8, 3, at(cf, 0, 1.5, 0), Color3.fromRGB(120, 124, 128), M.Metal)
	D(m, Vector3.new(2.8, 0.1, 6), at(cf, 0, 3.45, 0), Color3.fromRGB(200, 196, 186), M.Fabric)
	for _, z in { -2, 0.5, 2.6 } do
		D(m, Vector3.new(3.1, 0.12, 0.4), at(cf, 0, 3.55, z), Color3.fromRGB(50, 34, 22), M.Leather)
	end
	D(m, Vector3.new(1.6, 0.03, 2), at(cf, 0.3, 3.52, -0.6), C.Blood, M.SmoothPlastic)
	return m
end

function Props.LabBench(parent, cf: CFrame, w: number)
	local m = Build.Model(parent, "LabBench")
	P(m, Vector3.new(w, 3.2, 2.6), at(cf, 0, 1.6, 0), Color3.fromRGB(70, 74, 78), M.Metal)
	P(m, Vector3.new(w + 0.2, 0.25, 2.8), at(cf, 0, 3.3, 0), C.Black, M.Slate)
	local rng = Build.Rng(w * 10)
	for x = -w / 2 + 0.8, w / 2 - 0.8, 1.2 do
		if rng:NextNumber() < 0.6 then
			local col = ({ Color3.fromRGB(80, 200, 140), Color3.fromRGB(200, 60, 60), Color3.fromRGB(120, 160, 230) })[rng:NextInteger(1, 3)]
			Cyl(m, 0.5, rng:NextNumber(0.8, 1.4), at(cf, x, 3.9, rng:NextNumber(-0.6, 0.6)), col, M.Glass, { decor = true, transparency = 0.3 })
		end
	end
	return m
end

function Props.Chalkboard(parent, cf: CFrame, w: number, h: number, text: string)
	local m = Build.Model(parent, "Chalkboard")
	D(m, Vector3.new(w + 0.4, h + 0.4, 0.2), cf * CFrame.new(0, 0, -0.1), C.DarkBrown, M.Wood)
	Build.Text(m, Vector3.new(w, h, 0.05), cf * CFrame.new(0, 0, -0.23), text, {
		bg = Color3.fromRGB(28, 36, 32),
		color = Color3.fromRGB(220, 220, 210),
		font = Enum.Font.SpecialElite,
		ppu = 30,
	})
	return m
end

function Props.Sheeted(parent, cf: CFrame, w: number, h: number, l: number)
	-- furniture covered by a dust sheet
	local m = Build.Model(parent, "Sheeted")
	P(m, Vector3.new(w, h, l), at(cf, 0, h / 2, 0), Color3.fromRGB(196, 190, 176), M.Fabric)
	D(m, Vector3.new(w + 0.4, 0.6, l + 0.4), at(cf, 0, 0.3, 0), Color3.fromRGB(186, 180, 166), M.Fabric)
	return m
end

function Props.Doll(parent, cf: CFrame)
	local m = Build.Model(parent, "Doll")
	D(m, Vector3.new(0.6, 0.8, 0.4), at(cf, 0, 0.4, 0), Color3.fromRGB(120, 30, 40), M.Fabric)
	Ball(m, 0.55, at(cf, 0, 1.05, 0).Position, Color3.fromRGB(230, 214, 200), M.SmoothPlastic, { decor = true })
	D(m, Vector3.new(0.08, 0.08, 0.05), at(cf, -0.1, 1.1, -0.27), C.Black, M.SmoothPlastic)
	D(m, Vector3.new(0.6, 0.35, 0.5), at(cf, 0, 1.3, 0.05), Color3.fromRGB(30, 20, 16), M.Fabric)
	return m
end

function Props.MusicBox(parent, cf: CFrame)
	local m = Build.Model(parent, "MusicBox")
	P(m, Vector3.new(1.6, 0.9, 1.2), at(cf, 0, 0.45, 0), C.Burgundy, M.Wood, { collide = false })
	D(m, Vector3.new(1.6, 0.1, 1.2), at(cf, 0, 1.3, 0.5) * CFrame.Angles(math.rad(-70), 0, 0), C.Burgundy, M.Wood)
	Ball(m, 0.35, at(cf, 0, 1.05, 0).Position, C.Gold, M.Metal, { decor = true })
	return m
end

function Props.Wheelchair(parent, cf: CFrame)
	local m = Build.Model(parent, "Wheelchair")
	for _, sx in { -1, 1 } do
		Cyl(m, 2.6, 0.2, at(cf, sx * 1.1, 1.3, 0.3) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(90)), C.Charcoal, M.Metal, { decor = true })
	end
	P(m, Vector3.new(2, 0.3, 2), at(cf, 0, 1.8, 0), C.DeepBurgundy, M.Leather, { collide = false })
	D(m, Vector3.new(2, 2.2, 0.2), at(cf, 0, 3, 1), C.DeepBurgundy, M.Leather)
	return m
end

-- Ambient dust motes for a room. Disabled locally by clients on low graphics.
function Props.Dust(parent, pos: Vector3, size: Vector3)
	local box = D(parent, size, CFrame.new(pos), Color3.new(), M.SmoothPlastic, { transparency = 1, name = "DustVolume" })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 2.5
	emitter.Lifetime = NumberRange.new(8, 14)
	emitter.Speed = NumberRange.new(0.1, 0.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.07)
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 1
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(230, 220, 200))
	emitter.Drag = 1
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = box
	Build.Tag(emitter, "AmbientParticles")
	return box
end

return Props
