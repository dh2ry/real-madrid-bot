--!nonstrict
-- THE GRAND AURELIA HOTEL - procedural, deterministic map builder.
--
-- Footprint X[-60,60] Z[-50,50], entrance on the south (Z = -50).
-- Levels: Basement -14, Ground 0, First 16, Second 32, Third 48, Roof 64.
-- Every room is furnished; interactive objects are registered with the services here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local Services = script.Parent.Parent.Services
local Run = require(Services.Run)
local Doors = require(Services.Doors)
local Pickups = require(Services.Pickups)
local Hiding = require(Services.Hiding)
local Puzzles = require(Services.Puzzles)
local Elevator = require(Services.Elevator)
local Interact = require(Services.Interact)

local Hotel = {}
Hotel.Refs = {}

local C = Config.Palette
local M = Enum.Material
local Y = Config.Floors
local V = Vector3.new
local At = Build.At
local P, D = Build.P, Build.D

local FACADE = Color3.fromRGB(72, 64, 58)
local STYLE = {
	G = { color = Color3.fromRGB(58, 30, 32), material = M.Marble, trim = C.DarkBrown },
	F1 = { color = Color3.fromRGB(84, 38, 42), material = M.Fabric, trim = C.Walnut },
	F2 = { color = Color3.fromRGB(74, 48, 34), material = M.Wood, trim = C.Gold },
	F3 = { color = Color3.fromRGB(78, 80, 86), material = M.Plaster, trim = Color3.fromRGB(60, 56, 52) },
	B = { color = Color3.fromRGB(70, 70, 72), material = M.Concrete },
}
local RIGHT = -math.pi / 2

local function door(c: number, w: number?, h: number?)
	return { c = c, w = w or 4.5, h = h or 9 }
end

local function wall(parent, floor: string, x1, z1, x2, z2, openings, style)
	return Build.Wall(parent, x1, z1, x2, z2, Y[floor], floor == "B" and 13 or 15, style or STYLE[floor], openings)
end

local function finish(parent, rect, floor: string, color: Color3, material: Enum.Material, holes)
	return Build.Slab(parent, rect, holes, Y[floor], 0.2, color, material, { name = "Floor" })
end

local function wp(floor: string, x: number, z: number)
	Run.AddWaypoint(floor, V(x, Y[floor], z))
end

local function concierge(floor: string, x: number, z: number, facing: string)
	table.insert(Run.ConciergeSpots, { cf = At(x, Y[floor], z, facing), floor = floor })
end

local function roomSign(parent, cf: CFrame, text: string)
	D(parent, Vector3.new(1.8, 1, 0.12), cf * CFrame.new(0, 0, -0.04), C.DimGold, M.Metal)
	Build.Text(parent, Vector3.new(1.6, 0.8, 0.05), cf * CFrame.new(0, 0, -0.12), text, { bg = C.Black, color = C.Gold, font = Enum.Font.Bodoni })
end

----------------------------------------------------------------------------------------
-- Shell: slabs, exterior walls, windows, cornices
----------------------------------------------------------------------------------------

local function exteriorWindows(parent, floor: string, windows, opts)
	opts = opts or {}
	local y = Y[floor]
	local h = 15
	local style = STYLE[floor]
	local inner = { color = style.color, material = style.material, thickness = 0.6, trim = style.trim }
	local outer = { color = floor == "G" and Color3.fromRGB(48, 44, 42) or FACADE, material = floor == "G" and M.Granite or M.Limestone, thickness = 0.6 }
	local outerBase = floor == "G" and 0 or -1
	local sides = {
		S = { -60.6, -49.7, 60.6, -49.7, -60.6, -50.3, 60.6, -50.3 },
		N = { -60.6, 49.7, 60.6, 49.7, -60.6, 50.3, 60.6, 50.3 },
		E = { 59.7, -50, 59.7, 50, 60.3, -50.6, 60.3, 50.6 },
		W = { -59.7, -50, -59.7, 50, -60.3, -50.6, -60.3, 50.6 },
	}
	for side, coords in sides do
		local list = windows[side] or {}
		local ops, opsOuter = {}, {}
		for _, w in list do
			local b = w.b or 0
			table.insert(ops, { c = w.c, w = w.w, h = w.h, b = b })
			if b == 0 then
				table.insert(opsOuter, { c = w.c, w = w.w, h = w.h - outerBase, b = 0 })
			else
				table.insert(opsOuter, { c = w.c, w = w.w, h = w.h, b = b - outerBase })
			end
		end
		Build.Wall(parent, coords[1], coords[2], coords[3], coords[4], y, h, inner, ops)
		Build.Wall(parent, coords[5], coords[6], coords[7], coords[8], y + outerBase, h - outerBase, outer, opsOuter)
		for _, w in list do
			if not w.door then
				local cy = y + (w.b or 0) + w.h / 2
				local cf
				if side == "S" then
					cf = At(w.c, cy, -49.4, "N")
				elseif side == "N" then
					cf = At(w.c, cy, 49.4, "S")
				elseif side == "E" then
					cf = At(59.4, cy, w.c, "W")
				else
					cf = At(-59.4, cy, w.c, "E")
				end
				Props.Window(parent, cf, w.w, w.h, {
					broken = w.broken or opts.broken,
					curtains = opts.curtains ~= false,
					curtain = opts.curtain,
				})
				-- exterior sill + lintel
				D(parent, Vector3.new(w.w + 1, 0.4, 0.8), cf * CFrame.new(0, -w.h / 2 - 0.2, 1.3), Color3.fromRGB(90, 82, 74), M.Limestone)
				D(parent, Vector3.new(w.w + 1.4, 0.8, 0.7), cf * CFrame.new(0, w.h / 2 + 0.4, 1.25), Color3.fromRGB(90, 82, 74), M.Limestone)
			end
		end
	end
	-- cornice band below each floor
	if floor ~= "G" then
		for _, spec in {
			{ Vector3.new(122.6, 0.8, 1.2), V(0, y - 0.6, -50.9) },
			{ Vector3.new(122.6, 0.8, 1.2), V(0, y - 0.6, 50.9) },
			{ Vector3.new(1.2, 0.8, 102.6), V(60.9, y - 0.6, 0) },
			{ Vector3.new(1.2, 0.8, 102.6), V(-60.9, y - 0.6, 0) },
		} do
			D(parent, spec[1], CFrame.new(spec[2]), Color3.fromRGB(96, 86, 74), M.Limestone)
		end
	end
end

local function slabs(parent)
	local footprint = { -60.6, -50.6, 60.6, 50.6 }
	-- ground slab (basement ceiling) with the basement stairwell opening
	Build.Slab(parent, footprint, { { 26, -50, 60, -40 } }, Y.G - 0.2, 0.8, Color3.fromRGB(60, 60, 62), M.Concrete, { name = "Slab" })
	Build.Slab(parent, footprint, nil, Y.F1 - 0.2, 0.8, Color3.fromRGB(94, 84, 74), M.Plaster, { name = "Slab" })
	Build.Slab(parent, footprint, { { -59, 45, -55, 49 } }, Y.F2 - 0.2, 0.8, Color3.fromRGB(80, 76, 70), M.Plaster, { name = "Slab" })
	Build.Slab(parent, footprint, nil, Y.F3 - 0.2, 0.8, Color3.fromRGB(46, 34, 26), M.Wood, { name = "Slab" })
	Build.Slab(parent, footprint, nil, 64, 1, Color3.fromRGB(64, 66, 70), M.Plaster, { name = "Roof" })
	-- basement floor + escape tunnel floor
	Build.Slab(parent, { -60.6, -50.6, 60.6, 50.6 }, nil, Y.B, 1, Color3.fromRGB(54, 54, 56), M.Concrete, { name = "Floor" })
	Build.Slab(parent, { -101, -35, -60.6, -25 }, nil, Y.B, 1, Color3.fromRGB(50, 50, 52), M.Concrete, { name = "Floor" })
end

----------------------------------------------------------------------------------------
-- Exterior: courtyard, fountain, lamps, trees, fence, rain, roof sign
----------------------------------------------------------------------------------------

local function rainEmitter(parent, pos: Vector3, size: Vector3, rate: number)
	local box = D(parent, size, CFrame.new(pos), Color3.new(), M.SmoothPlastic, { transparency = 1, name = "RainCloud" })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(170, 185, 210))
	e.LightEmission = 0.15
	e.LightInfluence = 0.6
	e.Transparency = NumberSequence.new(0.45)
	e.Size = NumberSequence.new(0.09)
	e.Squash = NumberSequence.new(3.5)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Speed = NumberRange.new(95, 110)
	e.Lifetime = NumberRange.new(0.9, 1)
	e.Rate = rate
	e.Acceleration = Vector3.new(4, 0, 2)
	e.Parent = box
	Build.Tag(e, "Rain")
end

local function lampPost(parent, x: number, z: number, faulty: boolean)
	local m = Build.Model(parent, "LampPost")
	Build.Cyl(m, 0.5, 11, V(x, 5.5, z), C.Black, M.Metal)
	Build.Cyl(m, 1.2, 0.6, V(x, 0.3, z), C.Black, M.Metal)
	D(m, Vector3.new(1.6, 0.3, 1.6), CFrame.new(x, 11, z), C.Black, M.Metal)
	local glass = D(m, Vector3.new(1.2, 1.6, 1.2), CFrame.new(x, 12, z), Color3.fromRGB(255, 220, 160), M.Neon, { name = "Bulb", transparency = 0.15 })
	D(m, Vector3.new(1.8, 0.4, 1.8), CFrame.new(x, 13, z), C.Black, M.Metal)
	local light = Build.Light(glass, "PointLight", { Range = 26, Brightness = 1.3, Color = Color3.fromRGB(255, 205, 140), Shadows = true }, "Ext")
	if faulty then
		light:SetAttribute("Faulty", true)
	end
end

local function deadTree(parent, x: number, z: number, seed: number)
	local m = Build.Model(parent, "DeadTree")
	local rng = Build.Rng(seed)
	local h = rng:NextNumber(14, 20)
	local bark = Color3.fromRGB(38, 32, 28)
	P(m, Vector3.new(1.4, h, 1.4), CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.06, 0.06)), bark, M.Wood)
	for i = 1, 7 do
		local y = h * rng:NextNumber(0.45, 0.95)
		local len = rng:NextNumber(4, 8)
		local a = rng:NextNumber(0, math.pi * 2)
		local branch = CFrame.new(x, y, z) * CFrame.Angles(0, a, 0) * CFrame.Angles(rng:NextNumber(0.5, 1.1), 0, 0) * CFrame.new(0, len / 2, 0)
		D(m, Vector3.new(0.5, len, 0.5), branch, bark, M.Wood)
		if i % 2 == 0 then
			D(m, Vector3.new(0.25, len * 0.6, 0.25), branch * CFrame.new(0, len / 2, 0) * CFrame.Angles(0.6, 0, 0) * CFrame.new(0, len * 0.3, 0), bark, M.Wood)
		end
	end
end

local function exterior(parent)
	local ext = Build.Folder(parent, "Exterior")
	-- ground with a hole for the hotel footprint
	Build.Slab(ext, { -170, -175, 170, 150 }, { { -60.6, -50.6, 60.6, 50.6 } }, 0, 2, Color3.fromRGB(34, 36, 30), M.Ground, { name = "Ground" })
	-- driveway + forecourt
	D(ext, Vector3.new(16, 0.1, 64), CFrame.new(0, 0.05, -82), Color3.fromRGB(40, 40, 42), M.Asphalt)
	D(ext, Vector3.new(60, 0.1, 10), CFrame.new(0, 0.06, -55.6), Color3.fromRGB(64, 60, 56), M.Cobblestone)
	for _, x in { -9, 9 } do
		D(ext, Vector3.new(1, 0.4, 64), CFrame.new(x, 0.2, -82), Color3.fromRGB(80, 76, 70), M.Concrete)
	end
	-- entrance canopy
	P(ext, Vector3.new(18, 1, 9), CFrame.new(0, 12, -55), C.DeepBurgundy, M.Fabric)
	D(ext, Vector3.new(18.4, 0.4, 9.4), CFrame.new(0, 11.4, -55), C.Gold, M.Metal)
	for _, x in { -8, 8 } do
		Build.Cyl(ext, 0.8, 11.5, V(x, 5.75, -59), C.Gold, M.Metal)
	end
	Props.Sconce(ext, At(-6.5, 8, -50.7, "S"), "Ext", { brightness = 1.2, range = 16 })
	Props.Sconce(ext, At(6.5, 8, -50.7, "S"), "Ext", { brightness = 1.2, range = 16 })
	-- facade lettering above the canopy (some letters dead)
	local _, sign = Build.Text(ext, Vector3.new(30, 3.5, 0.2), At(0, 20, -50.95, "S"), "غراند أوريليا", {
		bgTransparency = 1,
		color = Color3.fromRGB(255, 205, 130),
		font = Enum.Font.Bodoni,
		lightInfluence = 0,
		brightness = 1.6,
	})
	Hotel.Refs.FacadeSign = sign
	Build.Text(ext, Vector3.new(10, 1.6, 0.2), At(0, 17.6, -50.95, "S"), "ف  ن  د  ق", {
		bgTransparency = 1,
		color = Color3.fromRGB(200, 170, 120),
		font = Enum.Font.Bodoni,
		lightInfluence = 0.5,
	})
	-- roof sign frame + letters
	for _, x in { -24, 24 } do
		D(ext, Vector3.new(0.6, 10, 0.6), CFrame.new(x, 69, -44), C.Rust, M.CorrodedMetal)
	end
	D(ext, Vector3.new(50, 0.6, 0.6), CFrame.new(0, 66, -44), C.Rust, M.CorrodedMetal)
	Build.Text(ext, Vector3.new(46, 6, 0.3), At(0, 70, -44.3, "S"), "فندق غراند أوريليا", {
		bgTransparency = 1,
		color = Color3.fromRGB(150, 40, 36),
		font = Enum.Font.Bodoni,
		lightInfluence = 0.3,
		brightness = 1,
	})
	-- roof parapet + water tank
	for _, spec in {
		{ Vector3.new(122, 3, 1), V(0, 65.5, -50.1) },
		{ Vector3.new(122, 3, 1), V(0, 65.5, 50.1) },
		{ Vector3.new(1, 3, 100), V(60.1, 65.5, 0) },
		{ Vector3.new(1, 3, 100), V(-60.1, 65.5, 0) },
	} do
		P(ext, spec[1], CFrame.new(spec[2]), FACADE, M.Limestone)
	end
	Build.Cyl(ext, 10, 9, V(-35, 70.5, 30), C.Rust, M.CorrodedMetal)
	for _, x in { -39, -31 } do
		for _, z in { 26, 34 } do
			D(ext, Vector3.new(0.6, 6, 0.6), CFrame.new(x, 67, z), C.Charcoal, M.Metal)
		end
	end
	-- fountain
	local fountain = Build.Model(ext, "Fountain")
	Build.Cyl(fountain, 18, 2, V(0, 1, -85), Color3.fromRGB(90, 86, 80), M.Limestone)
	Build.Cyl(fountain, 16, 0.3, V(0, 1.9, -85), Color3.fromRGB(20, 26, 28), M.Glass, { decor = true, transparency = 0.2, reflect = 0.2 })
	Build.Cyl(fountain, 3, 6, V(0, 3, -85), Color3.fromRGB(90, 86, 80), M.Limestone)
	Build.Cyl(fountain, 7, 0.8, V(0, 6, -85), Color3.fromRGB(90, 86, 80), M.Limestone)
	local statue = Color3.fromRGB(110, 110, 104)
	P(fountain, Vector3.new(1.4, 3, 1), CFrame.new(0, 8, -85), statue, M.Marble)
	Build.Ball(fountain, 1.1, V(0, 10.1, -85), statue, M.Marble)
	for _, sx in { -1, 1 } do
		D(fountain, Vector3.new(3, 2.4, 0.2), CFrame.new(sx * 1.6, 8.8, -84.4) * CFrame.Angles(0, sx * 0.5, sx * 0.5), statue, M.Marble)
	end
	D(fountain, Vector3.new(0.6, 0.8, 0.6), CFrame.new(1.2, 2.3, -79), statue, M.Marble) -- broken-off hand in the basin
	-- lamps, trees, car, benches
	for i, z in { -62, -78, -94, -110 } do
		lampPost(ext, -11, z, i == 2)
		lampPost(ext, 11, z, i == 3)
	end
	for i, pos in { V(-35, 0, -70), V(-48, 0, -100), V(36, 0, -76), V(52, 0, -105), V(-75, 0, -30), V(78, 0, 10), V(-80, 0, 40) } do
		deadTree(ext, pos.X, pos.Z, i * 13)
	end
	local car = Build.Model(ext, "OldCar")
	local carCf = CFrame.new(-28, 0, -98) * CFrame.Angles(0, math.rad(20), 0)
	P(car, Vector3.new(6, 2.4, 14), carCf * CFrame.new(0, 2, 0), Color3.fromRGB(52, 20, 22), M.Metal)
	P(car, Vector3.new(5.6, 2, 7), carCf * CFrame.new(0, 4, 1), Color3.fromRGB(52, 20, 22), M.Metal)
	D(car, Vector3.new(5.4, 1.6, 0.2), carCf * CFrame.new(0, 4.1, -2.5), Color3.fromRGB(40, 50, 60), M.Glass, { transparency = 0.4 })
	for _, sx in { -3, 3 } do
		for _, sz in { -4.5, 4.5 } do
			Build.Cyl(car, 2.4, 0.9, carCf * CFrame.new(sx, 1.2, sz) * CFrame.Angles(0, 0, math.rad(90)), C.Black, M.Rubber, { decor = true })
		end
	end
	-- hedges + iron fence
	for _, spec in { { -60, -88 }, { 60, -88 } } do
		P(ext, Vector3.new(66, 6, 4), CFrame.new(spec[1] * 1.08, 3, spec[2] + 30) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(22, 34, 22), M.LeafyGrass)
	end
	for x = -98, 98, 4 do
		if math.abs(x) > 8 then
			D(ext, Vector3.new(0.3, 9, 0.3), CFrame.new(x, 4.5, -125), C.Black, M.Metal)
			D(ext, Vector3.new(0.5, 0.8, 0.5), CFrame.new(x, 9.2, -125), C.Black, M.Metal)
		end
	end
	for _, spec in { { -53, 2 }, { 53, 2 } } do
		D(ext, Vector3.new(90, 0.4, 0.3), CFrame.new(spec[1], 8, -125), C.Black, M.Metal)
		D(ext, Vector3.new(90, 0.4, 0.3), CFrame.new(spec[1], 1.5, -125), C.Black, M.Metal)
	end
	for _, x in { -7, 7 } do
		P(ext, Vector3.new(2.5, 12, 2.5), CFrame.new(x, 6, -125), Color3.fromRGB(70, 66, 60), M.Limestone)
		Build.Ball(ext, 1.6, V(x, 12.8, -125), Color3.fromRGB(70, 66, 60), M.Limestone)
	end
	-- the gate stands open (the hotel wants guests)
	for i, sx in { -1, 1 } do
		local hinge = CFrame.new(sx * 6, 0, -125) * CFrame.Angles(0, sx * math.rad(-75), 0)
		for b = 0, 5 do
			D(ext, Vector3.new(0.25, 10, 0.25), hinge * CFrame.new(-sx * (0.5 + b), 5, 0), C.Black, M.Metal)
		end
		D(ext, Vector3.new(6, 0.4, 0.3), hinge * CFrame.new(-sx * 3, 9.2, 0), C.Black, M.Metal, { name = "Gate" .. i })
	end
	-- invisible world boundary
	for _, spec in {
		{ Vector3.new(220, 60, 2), V(0, 30, -128) },
		{ Vector3.new(220, 60, 2), V(0, 30, 82) },
		{ Vector3.new(2, 60, 212), V(-104, 30, -23) },
		{ Vector3.new(2, 60, 212), V(104, 30, -23) },
	} do
		P(ext, spec[1], CFrame.new(spec[2]), Color3.new(), M.SmoothPlastic, { transparency = 1, name = "Boundary" })
	end
	-- rain (outside only)
	rainEmitter(ext, V(0, 75, -90), Vector3.new(200, 1, 70), 900)
	rainEmitter(ext, V(-82, 75, 15), Vector3.new(40, 1, 140), 350)
	rainEmitter(ext, V(82, 75, 15), Vector3.new(40, 1, 140), 350)
	rainEmitter(ext, V(0, 75, 66), Vector3.new(130, 1, 30), 300)
	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CourtyardSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, -0.45, -108)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = ext
	Run.SetPoint("Courtyard", CFrame.new(0, 3, -105))
	Run.SetPoint("MenuCamera", CFrame.lookAt(V(-34, 9, -118), V(0, 22, -50)))
end

----------------------------------------------------------------------------------------
-- Furnished guest room template
----------------------------------------------------------------------------------------

-- forward = direction from the room centre to the door wall. W = width, Dp = depth.
local function bedroom(parent, floor: string, cx: number, cz: number, forward: Vector3, W: number, Dp: number, opts)
	opts = opts or {}
	local y = Y[floor]
	local base = CFrame.lookAt(V(cx, y, cz), V(cx, y, cz) + forward)
	local function L(x: number, z: number, rot: number?)
		return base * CFrame.new(x, 0, z) * CFrame.Angles(0, rot or 0, 0)
	end
	local abandoned = floor == "F3"
	local lightZone = if opts.dark then nil else floor
	local bed = Props.Bed(parent, L(0, Dp / 2 - 5.1), {
		messy = opts.messy or abandoned,
		blanket = abandoned and Color3.fromRGB(70, 60, 56) or opts.blanket,
		sheet = abandoned and Color3.fromRGB(150, 140, 120) or nil,
	})
	Hiding.Add(bed)
	Props.Nightstand(parent, L(-5, Dp / 2 - 1.4), not abandoned and lightZone or nil)
	Props.Nightstand(parent, L(5, Dp / 2 - 1.4), nil)
	if not opts.noWardrobe then
		Hiding.Add(Props.Wardrobe(parent, L(-W / 2 + 1.8, Dp / 2 - 11, RIGHT)))
	end
	Props.Desk(parent, L(W / 2 - 1.7, Dp / 2 - 12, RIGHT), { width = 5, lamp = not abandoned, zone = lightZone })
	Props.Armchair(parent, L(W / 2 - 4, -Dp / 2 + 7, math.rad(200)), { color = abandoned and Color3.fromRGB(80, 60, 56) or C.Burgundy })
	Props.Rug(parent, L(0, 2), math.min(W - 6, 12), 9, abandoned and Color3.fromRGB(60, 40, 38) or C.Burgundy)
	Props.Painting(parent, base * CFrame.new(0, 9.5, Dp / 2 - 0.45), 5, 3.4, opts.painting or "hotel", math.floor(cx + cz))
	if not opts.noLamp then
		local pendant = Props.Pendant(parent, (base * CFrame.new(0, 15, 0)).Position, floor, { brightness = abandoned and 0.8 or 1, color = abandoned and C.ColdBlue or nil })
		if abandoned or opts.faulty then
			for _, d in pendant:GetDescendants() do
				if d:IsA("Light") then
					d:SetAttribute("Faulty", true)
				end
			end
		end
	end
	Props.Suitcase(parent, L(-W / 2 + 4, -Dp / 2 + 5, 0.4), { lying = opts.messy or abandoned })
	if opts.messy or abandoned then
		Props.Chair(parent, L(2, -2, 0.7), { fallen = true })
		Props.BloodStain(parent, (L(1.5, Dp / 2 - 10)).Position, 2.4, math.floor(cx))
	end
	if abandoned then
		Props.Debris(parent, (L(-2, -4)).Position, 8, math.floor(cx + 100))
	end
	Props.Dust(parent, V(cx, y + 6, cz), Vector3.new(W - 4, 8, Dp - 4))
	wp(floor, cx, cz)
	return base, L
end

----------------------------------------------------------------------------------------
-- GROUND FLOOR
----------------------------------------------------------------------------------------

local function groundFloor(parent)
	local g = Build.Folder(parent, "GroundFloor")
	local y = Y.G
	exteriorWindows(g, "G", {
		S = {
			{ c = -50, w = 5, h = 9, b = 2 },
			{ c = -30, w = 5, h = 9, b = 2 },
			{ c = -13, w = 4, h = 7, b = 3 },
			{ c = 0, w = 10, h = 11, door = true },
			{ c = 13, w = 4, h = 7, b = 3 },
			{ c = 40, w = 3, h = 4, b = 7 },
		},
		W = { { c = -40, w = 5, h = 9, b = 2 }, { c = -12, w = 5, h = 9, b = 2 }, { c = 5, w = 4, h = 7, b = 3 }, { c = 25, w = 4, h = 7, b = 3 } },
		E = { { c = -25, w = 4, h = 7, b = 3 }, { c = -2, w = 4, h = 7, b = 3 }, { c = 32, w = 4, h = 7, b = 3 }, { c = 44, w = 4, h = 7, b = 3 } },
		N = { { c = 30, w = 4, h = 5, b = 6 }, { c = 52, w = 4, h = 7, b = 3 } },
	})
	-- interior walls
	wall(g, "G", -20, -50, -20, 12, { door(-25, 8, 10), door(6, 5) })
	wall(g, "G", -60, 0, -20, 0, { door(-40, 5) })
	wall(g, "G", -60, 30, -20, 30, { door(-30, 5) })
	wall(g, "G", -20, 12, -20, 50)
	wall(g, "G", -20, 12, 20, 12, { door(-14, 5), door(0, 12, 12) })
	wall(g, "G", -8, 12, -8, 50, { door(40, 5) })
	wall(g, "G", 8, 12, 8, 50, { door(20, 5) })
	wall(g, "G", -20, 30, -8, 30)
	wall(g, "G", 20, -50, 20, 12, { door(0, 5), door(-30, 5) })
	wall(g, "G", 20, 12, 20, 50, { door(40, 5) })
	wall(g, "G", 20, 20, 44, 20)
	wall(g, "G", 44, -10, 44, 50, { door(35, 5) })
	wall(g, "G", 20, -10, 60, -10, { door(52, 5) })
	wall(g, "G", 20, -40, 60, -40, { door(23, 4) })

	-- floor finishes
	finish(g, { -20, -50, 20, 12 }, "G", Color3.fromRGB(20, 18, 20), M.Marble)
	finish(g, { -60, -50, -20, 0 }, "G", Color3.fromRGB(58, 38, 28), M.WoodPlanks)
	finish(g, { -60, 0, -20, 30 }, "G", Color3.fromRGB(66, 20, 26), M.Carpet)
	finish(g, { -60, 30, -20, 50 }, "G", Color3.fromRGB(64, 64, 64), M.Concrete)
	finish(g, { -20, 12, -8, 50 }, "G", Color3.fromRGB(70, 46, 32), M.Wood)
	finish(g, { -8, 12, 8, 50 }, "G", Color3.fromRGB(24, 20, 22), M.Marble)
	finish(g, { 8, 12, 20, 50 }, "G", Color3.fromRGB(60, 44, 34), M.WoodPlanks)
	finish(g, { 20, -10, 44, 20 }, "G", Color3.fromRGB(56, 58, 60), M.Slate)
	finish(g, { 20, -40, 60, -10 }, "G", Color3.fromRGB(52, 20, 26), M.Carpet)
	finish(g, { 44, -10, 60, 50 }, "G", Color3.fromRGB(62, 38, 26), M.Wood)
	finish(g, { 20, 20, 44, 50 }, "G", Color3.fromRGB(110, 104, 96), M.CeramicTiles)
	finish(g, { 20, -50, 26, -40 }, "G", Color3.fromRGB(24, 20, 22), M.Marble)

	------------------------------------------------------------------ LOBBY
	local lobby = Build.Folder(g, "Lobby")
	for _, x in { -5, 5 } do
		D(lobby, Vector3.new(0.4, 0.05, 58), CFrame.new(x, y + 0.03, -20), C.Gold, M.Metal)
	end
	Props.Rug(lobby, At(0, y, -26, "S"), 7, 42, C.Burgundy, C.Gold)
	for _, x in { -12, 12 } do
		for _, z in { -40, -20 } do
			Props.Column(lobby, V(x, y, z), 15)
		end
	end
	for _, z in { -40, -24, -8 } do
		Props.Chandelier(lobby, V(0, y + 15, z), "G", { shadows = z == -24, brightness = 1.6, range = 32 })
	end
	Props.Counter(lobby, At(0, y, 2, "S"), 16, { name = "ReceptionDesk" })
	local _, bellDome = Props.Bell(lobby, CFrame.new(2, y + 3.7, 1.4))
	Hotel.Refs.Bell = bellDome
	Props.DeskLamp(lobby, CFrame.new(-6, y + 3.7, 2.2), "G")
	D(lobby, Vector3.new(2, 0.3, 1.4), CFrame.new(-1, y + 3.85, 1.6) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(70, 24, 24), M.Leather) -- guest register
	local _, phoneBase = Props.Phone(lobby, CFrame.new(5.5, y + 3.7, 1.8) * CFrame.Angles(0, math.rad(200), 0))
	Hotel.Refs.ReceptionPhone = phoneBase
	Pickups.Document(lobby, CFrame.new(-3.4, y + 3.72, 1.2), "welcome_card")
	Hotel.Refs.DeskKeyCF = CFrame.new(3.6, y + 3.72, 1.0)
	Hotel.Refs.ConciergeDesk = At(0, y, 6.5, "S")
	-- key cabinet + plaque
	D(lobby, Vector3.new(8, 5, 0.3), CFrame.new(14, y + 6, 11.45), C.Walnut, M.Wood)
	for i = 0, 11 do
		local kx, ky = 11 + (i % 6) * 1.2, y + 7.4 - math.floor(i / 6) * 2
		D(lobby, Vector3.new(0.1, 0.1, 0.4), CFrame.new(kx, ky, 11.2), C.Gold, M.Metal)
		if i ~= 6 then
			D(lobby, Vector3.new(0.2, 0.7, 0.05), CFrame.new(kx, ky - 0.45, 11.05), C.Gold, M.Metal)
		end
	end
	Build.Text(lobby, Vector3.new(14, 1.6, 0.1), At(0, y + 13.3, 11.5, "S"), "غراند أوريليا  ·  تأسس عام 1931", { bg = C.Black, color = C.Gold, font = Enum.Font.Bodoni })
	-- seating areas
	Props.Sofa(lobby, At(-17, y, -34, "E"), { width = 7 })
	Props.CoffeeTable(lobby, At(-13, y, -34, "E"))
	Props.Armchair(lobby, At(-8.8, y, -34, "W"))
	Props.Sofa(lobby, At(17, y, -34, "W"), { width = 7, torn = true })
	Props.CoffeeTable(lobby, At(13, y, -34, "W"))
	Props.Armchair(lobby, At(8.8, y, -34, "E"))
	Props.GrandfatherClock(lobby, At(-19.1, y, -8, "E"))
	for _, pos in { V(-18, y, -48), V(18, y, -48), V(-18, y, 10), V(18, y, 10) } do
		Props.Plant(lobby, CFrame.new(pos), { seed = math.floor(pos.X + pos.Z) })
	end
	Props.Cart(lobby, At(12, y, -45, "N"), { luggage = true })
	Props.Suitcase(lobby, At(-10, y, -46, "N"), { lying = true })
	Props.Suitcase(lobby, At(7, y, -8, "W"), { color = C.Burgundy })
	Props.Painting(lobby, At(-19.55, y + 7, -40, "E"), 4, 5.5, "portrait", 1)
	Props.Painting(lobby, At(-19.55, y + 7, -12, "E"), 6, 4, "hotel", 2)
	Props.Painting(lobby, At(19.55, y + 7, -15, "W"), 4, 5.5, "eyes", 3)
	Props.Painting(lobby, At(19.55, y + 7, -42, "W"), 4, 5.5, "portrait", 4)
	Props.Sconce(lobby, At(-7.5, y + 8, -49.35, "N"), "G")
	Props.Sconce(lobby, At(7.5, y + 8, -49.35, "N"), "G")
	Props.BloodStain(lobby, V(5, y, -3), 2.6, 11)
	Props.DragMarks(lobby, V(5, y, -3), V(14, y, 8))
	Props.Dust(lobby, V(0, y + 7, -20), Vector3.new(36, 12, 56))
	Doors.Add(g, {
		id = "FrontDoor",
		cf = At(0, y, -50, "S"),
		w = 10,
		h = 11,
		style = "grand",
		double = true,
		label = "مدخل الفندق",
		locked = true,
		lockedText = "الأبواب لا تتزحزح. (اضغط «العب» للبدء)",
	})
	Run.SetPoint("Lobby", CFrame.new(0, y + 3, -30))
	concierge("G", 0, 6.5, "S")
	concierge("G", -56, -46, "N")
	concierge("G", 0, 30, "S")
	concierge("G", 56, -30, "W")
	for _, p in { { -14, -30 }, { 14, -30 }, { 0, -14 }, { -14, 0 }, { 14, 0 }, { 0, -44 } } do
		wp("G", p[1], p[2])
	end

	------------------------------------------------------------------ RESTAURANT
	local rest = Build.Folder(g, "Restaurant")
	for _, x in { -48, -32 } do
		for i, z in { -40, -28, -16 } do
			Props.DiningTable(rest, At(x, y, z, "N"), {
				width = 4,
				length = 6,
				seats = 2,
				blood = x == -32 and z == -16,
				fallenChair = (x == -32 and z == -16) and 1 or nil,
				candleLight = i == 2,
			})
		end
	end
	Props.DiningTable(rest, At(-55, y, -6, "N"), { width = 3, length = 3, seats = 1, candles = false, cloth = C.Burgundy })
	Props.Cloche(rest, CFrame.new(-55.4, y + 3.27, -6.4))
	Pickups.Add(rest, CFrame.new(-54.4, y + 3.27, -5.6), "ReceptionKey")
	Pickups.Document(rest, CFrame.new(-47.2, y + 3.27, -39.2), "last_menu")
	Props.Counter(rest, At(-57.6, y, -25, "E"), 18, { name = "Buffet", top = C.Bone, topMaterial = M.Fabric })
	Props.Candelabra(rest, At(-57.6, y + 3.7, -32, "E"))
	Props.Candelabra(rest, At(-57.6, y + 3.7, -18, "E"))
	Pickups.Add(rest, CFrame.new(-57.4, y + 3.72, -25), "Battery")
	for _, z in { -36, -14 } do
		Props.Chandelier(rest, V(-40, y + 15, z), "G", { brightness = 1.2 })
	end
	Props.Painting(rest, At(-52, y + 8, -0.45, "S"), 5, 4, "hotel", 5)
	Props.Painting(rest, At(-28, y + 8, -0.45, "S"), 4, 5, "portrait", 6)
	Props.Dust(rest, V(-40, y + 7, -25), Vector3.new(36, 10, 46))
	Doors.Add(g, { id = "RestaurantDoor", cf = At(-20, y, -25, "E"), w = 8, h = 10, style = "grand", double = true, label = "المطعم" })
	for _, p in { { -40, -46 }, { -40, -22 }, { -40, -8 }, { -54, -30 }, { -26, -34 } } do
		wp("G", p[1], p[2])
	end

	------------------------------------------------------------------ LOUNGE
	local lounge = Build.Folder(g, "Lounge")
	Props.Fireplace(lounge, At(-58.6, y, 15, "E"))
	Props.Painting(lounge, At(-59.5, y + 10.5, 15, "E"), 4.5, 3.4, "eyes", 7)
	Props.Rug(lounge, At(-50, y, 15, "E"), 12, 14, C.DeepBurgundy)
	Props.Sofa(lounge, At(-47, y, 15, "W"), { width = 8 })
	Props.Armchair(lounge, At(-52, y, 7, "N"))
	Props.Armchair(lounge, At(-52, y, 23, "S"))
	Props.CoffeeTable(lounge, At(-52, y, 15, "W"))
	Pickups.Add(lounge, CFrame.new(-52, y + 1.75, 15.5), "Bandage")
	Props.Piano(lounge, At(-30, y, 18, "S"))
	Props.Shelf(lounge, At(-50, y, 28.9, "S"), { width = 8 })
	Hiding.Add(Props.Wardrobe(lounge, At(-21.8, y, 25, "W")))
	Props.Chandelier(lounge, V(-40, y + 15, 15), "G")
	Props.Dust(lounge, V(-40, y + 7, 15), Vector3.new(36, 10, 26))
	Doors.Add(g, { id = "LoungeDoor", cf = At(-20, y, 6, "E"), w = 5, style = "wood", label = "الصالة" })
	Doors.Add(g, { id = "RestLoungeDoor", cf = At(-40, y, 0, "N"), w = 5, style = "wood", label = "الصالة" })
	for _, p in { { -40, 8 }, { -40, 24 }, { -26, 8 } } do
		wp("G", p[1], p[2])
	end

	------------------------------------------------------------------ STORAGE (breaker)
	local storage = Build.Folder(g, "Storage")
	Puzzles.Breaker(storage, At(-59.6, y, 40, "E"))
	Props.Shelf(storage, At(-46, y, 48.9, "S"), { width = 8, fill = "boxes", seed = 21 })
	Props.Shelf(storage, At(-34, y, 48.9, "S"), { width = 8, fill = "boxes", seed = 22 })
	Props.Crate(storage, At(-50, y, 34, "N"))
	Props.Crate(storage, At(-47, y, 33.5, "N"), 2.4)
	Props.Barrel(storage, At(-26, y, 46, "N"))
	Props.Cart(storage, At(-38, y, 36, "E"))
	Hiding.Add(Props.Locker(storage, At(-21.8, y, 40, "W")))
	Pickups.Add(storage, CFrame.new(-50, y + 3, 34), "Battery")
	local storageLamp = Props.Pendant(storage, V(-40, y + 15, 40), "G", { brightness = 0.8, color = C.ColdBlue })
	for _, d in storageLamp:GetDescendants() do
		if d:IsA("Light") then
			d:SetAttribute("Faulty", true)
		end
	end
	Props.Candle(storage, V(-57, y + 0, 44))
	Doors.Add(g, { id = "StorageDoor", cf = At(-30, y, 30, "S"), w = 5, style = "wood", label = "غرفة التخزين" })
	Run.SetPoint("Storage", CFrame.new(-40, y + 3, 40))
	wp("G", -40, 40)

	------------------------------------------------------------------ RECEPTION OFFICE
	local office = Build.Folder(g, "ReceptionOffice")
	Props.Desk(office, At(-14, y, 23, "S"), { width = 5.5, lamp = true, zone = "G" })
	Pickups.Add(office, CFrame.new(-15.6, y + 3.17, 22.6), "Fuse")
	Pickups.Document(office, CFrame.new(-12.6, y + 3.17, 22.8), "reception_memo")
	Props.Shelf(office, At(-19.1, y, 18, "E"), { width = 6, fill = "boxes", seed = 31 })
	Hiding.Add(Props.Wardrobe(office, At(-10.8, y, 28.5, "S")))
	D(office, Vector3.new(3, 3, 0.4), CFrame.new(-17, y + 4, 29.4), C.Charcoal, M.Metal) -- wall safe
	Props.Pendant(office, V(-14, y + 15, 20), "G")
	Doors.Add(g, { id = "ReceptionOfficeDoor", cf = At(-14, y, 12, "S"), w = 5, style = "wood", label = "مكتب الاستقبال", locked = true, key = "ReceptionKey", lockedText = "مقفل. «الاستقبال - للموظفين فقط»." })
	wp("G", -14, 18)

	------------------------------------------------------------------ SWITCHBOARD
	local sw = Build.Folder(g, "Switchboard")
	local board = Build.Model(sw, "SwitchboardPanel")
	P(board, Vector3.new(1.5, 7, 10), CFrame.new(-19.2, y + 3.5, 40), C.Walnut, M.Wood)
	for row = 0, 5 do
		for col = 0, 7 do
			D(board, Vector3.new(0.1, 0.25, 0.25), CFrame.new(-18.4, y + 4.5 + row * 0.6, 36.5 + col * 1), C.Black, M.Metal)
		end
	end
	for i = 0, 5 do
		Props.Pipe(board, V(-18.3, y + 5 + (i % 3) * 0.6, 37 + i), V(-17.6, y + 3.6, 37.5 + i * 0.8), 0.08, C.Burgundy)
	end
	Build.Text(sw, Vector3.new(6, 0.8, 0.1), At(-18.35, y + 8.2, 40, "E"), "المقسم الهاتفي", { bg = C.Black, color = C.Gold, font = Enum.Font.Bodoni })
	Props.Chair(sw, At(-16.4, y, 40, "W"))
	Hiding.Add(Props.Locker(sw, At(-14, y, 48.4, "S")))
	Pickups.Add(sw, CFrame.new(-17.6, y + 3.05, 44), "Bandage")
	Props.Pendant(sw, V(-14, y + 15, 40), "G", { brightness = 0.7 })
	Doors.Add(g, { id = "SwitchboardDoor", cf = At(-8, y, 40, "E"), w = 5, style = "wood", label = "غرفة المقسم" })
	wp("G", -14, 40)

	------------------------------------------------------------------ ELEVATOR HALL
	local hall = Build.Folder(g, "ElevatorHall")
	for _, z in { 18, 30 } do
		Props.Sconce(hall, At(-7.55, y + 7.5, z, "E"), "G")
		Props.Sconce(hall, At(7.55, y + 7.5, z, "W"), "G")
	end
	Props.Painting(hall, At(7.55, y + 7, 26, "W"), 3.5, 4.5, "portrait", 9)
	Props.Plant(hall, CFrame.new(-6, y, 33), { seed = 4 })
	Run.SetPoint("Spur", CFrame.new(0, y + 3, 24))
	wp("G", 0, 22)

	------------------------------------------------------------------ LUGGAGE ROOM
	local lug = Build.Folder(g, "LuggageRoom")
	Props.Shelf(lug, At(18.9, y, 20, "W"), { width = 6, fill = "boxes", seed = 41 })
	Props.Shelf(lug, At(18.9, y, 29, "W"), { width = 6, fill = "boxes", seed = 42 })
	Props.Cart(lug, At(12, y, 40, "N"), { luggage = true })
	for i = 0, 3 do
		Props.Suitcase(lug, At(10 + (i % 2) * 3, y + math.floor(i / 2) * 1.9, 47.5, "S"), { color = i % 2 == 0 and C.Burgundy or nil })
	end
	Pickups.Add(lug, CFrame.new(16, y, 47), "Battery")
	Props.Pendant(lug, V(14, y + 15, 30), "G", { brightness = 0.8 })
	Doors.Add(g, { id = "LuggageDoor", cf = At(8, y, 20, "W"), w = 5, style = "wood", label = "غرفة الأمتعة" })
	Doors.Add(g, { id = "KitchenLuggageDoor", cf = At(20, y, 40, "W"), w = 5, style = "wood", label = "المطبخ" })
	wp("G", 14, 24)
	wp("G", 14, 44)

	------------------------------------------------------------------ SECURITY OFFICE
	local sec = Build.Folder(g, "SecurityOffice")
	Props.Counter(sec, At(42.4, y, 5, "W"), 12, { trim = false, color = Color3.fromRGB(60, 60, 62), material = M.Metal })
	for i, label in { "كاميرا 1\nالردهة", "كاميرا 3\nالطابق الثالث\nفُقدت الإشارة", "كاميرا 6\nالقبو\n▮▮▮", "كاميرا 7\nالغرفة 307" } do
		Props.Monitor(sec, At(42.8, y + 3.7, 0 + i * 2.6, "W"), label)
	end
	Props.Chair(sec, At(38.6, y, 5, "E"), { seat = C.Charcoal })
	Pickups.Add(sec, CFrame.new(41.6, y + 3.72, -0.4), "ElevatorCard")
	Pickups.Document(sec, CFrame.new(41.4, y + 3.72, 11.4), "security_log")
	Hiding.Add(Props.Locker(sec, At(26, y, 18.5, "S")))
	Hiding.Add(Props.Locker(sec, At(30, y, 18.5, "S")))
	Build.Text(sec, Vector3.new(8, 6, 0.1), At(20.45, y + 6, 10, "E"), "غراند أوريليا\nخطة الطوارئ\n\nالقبو - الغلاية · المولّد\nالأرضي - الردهة · الاستقبال\n1 - الغرف 101-109\n2 - الأجنحة · المكتبة\n3 - الغرف 301-308", {
		bg = Color3.fromRGB(220, 210, 180),
		color = C.Black,
		font = Enum.Font.SpecialElite,
	})
	Props.HandPrint(sec, At(43.55, y + 6, 14, "W"))
	local secLamp = Props.Pendant(sec, V(32, y + 15, 5), "G", { color = C.ColdBlue })
	for _, d in secLamp:GetDescendants() do
		if d:IsA("Light") then
			d:SetAttribute("Faulty", true)
		end
	end
	Doors.Add(g, {
		id = "SecurityDoor",
		cf = At(20, y, 0, "W"),
		w = 5,
		style = "metal",
		label = "مكتب الأمن",
		locked = true,
		lockedText = "مقفل. لوحة أرقام بجانب الباب تنتظر رمزًا.",
	})
	Puzzles.Keypad(g, At(19.5, y + 4.8, 3.8, "W"), {
		id = "Security",
		code = Config.Codes.Security,
		title = "مكتب الأمن",
		zone = "G",
		onSolved = function()
			Doors.Unlock("SecurityDoor")
			Doors.SetOpen("SecurityDoor", true)
		end,
	})
	wp("G", 30, 5)

	------------------------------------------------------------------ CLOAKROOM + BASEMENT DOOR
	local cloak = Build.Folder(g, "Cloakroom")
	Props.Counter(cloak, At(32, y, -25, "W"), 10)
	for _, rx in { 44, 52 } do
		D(cloak, Vector3.new(0.3, 0.3, 22), CFrame.new(rx, y + 8, -25), C.Gold, M.Metal)
		for _, z in { -35, -15 } do
			D(cloak, Vector3.new(0.3, 8, 0.3), CFrame.new(rx, y + 4, z), C.Gold, M.Metal)
		end
		for i = 0, 7 do
			local col = ({ C.Black, C.DeepBurgundy, C.DarkBrown, Color3.fromRGB(40, 44, 50) })[i % 4 + 1]
			D(cloak, Vector3.new(2.2, 5, 0.6), CFrame.new(rx, y + 5.4, -34 + i * 2.6) * CFrame.Angles(0, math.rad(90), 0), col, M.Fabric)
		end
	end
	Hiding.Add(Props.Wardrobe(cloak, At(58.2, y, -30, "W")))
	Props.Suitcase(cloak, At(36, y, -36, "N"), { lying = true })
	Props.DragMarks(cloak, V(36, y, -18), V(24, y, -38))
	Props.BloodStain(cloak, V(23, y, -38), 1.8, 23)
	Build.Text(cloak, Vector3.new(6, 1, 0.1), At(23, y + 10, -39.5, "N"), "القبو - ممنوع الدخول", { bg = Color3.fromRGB(150, 20, 20), color = C.Bone, font = Enum.Font.GothamBold })
	Props.Pendant(cloak, V(40, y + 15, -25), "G", { brightness = 0.8 })
	Doors.Add(g, { id = "CloakroomDoor", cf = At(20, y, -30, "W"), w = 5, style = "wood", label = "غرفة المعاطف" })
	Doors.Add(g, { id = "BarDoor", cf = At(52, y, -10, "S"), w = 5, style = "wood", label = "البار" })
	Doors.Add(g, {
		id = "BasementDoor",
		cf = At(23, y, -40, "N"),
		w = 4,
		style = "steel",
		label = "القبو",
		locked = true,
		key = "BasementKey",
		lockedText = "باب حديدي ثقيل: «القبو - ممنوع الدخول». مقفل بإحكام.",
	})
	Run.SetPoint("Cloakroom", CFrame.new(32, y + 3, -18))
	wp("G", 30, -18)
	wp("G", 50, -30)

	------------------------------------------------------------------ BAR
	local bar = Build.Folder(g, "Bar")
	Props.Counter(bar, At(52, y, 15, "W"), 24, { name = "BarCounter" })
	for z = 5, 25, 4 do
		Props.Stool(bar, At(49.4, y, z, "E"))
	end
	Props.Shelf(bar, At(58.4, y, 9, "W"), { width = 8, fill = "bottles", seed = 51, rows = 4 })
	Props.Shelf(bar, At(58.4, y, 21, "W"), { width = 8, fill = "bottles", seed = 52, rows = 4 })
	for _, z in { 6, 15, 24 } do
		Props.Pendant(bar, V(52, y + 15, z), "G", { brightness = 0.9 })
	end
	for _, z in { -4, 36, 44 } do
		Props.DiningTable(bar, At(50, y, z, "N"), { width = 3, length = 3, seats = 1, candles = false, cloth = C.DeepBurgundy })
	end
	Pickups.Add(bar, CFrame.new(54.5, y, 30), "Bandage")
	Doors.Add(g, { id = "BarKitchenDoor", cf = At(44, y, 35, "E"), w = 5, style = "wood", label = "المطبخ" })
	wp("G", 48, 0)
	wp("G", 48, 30)

	------------------------------------------------------------------ KITCHEN
	local kitchen = Build.Folder(g, "Kitchen")
	Props.Stove(kitchen, At(28, y, 48.6, "S"))
	Props.Stove(kitchen, At(33, y, 48.6, "S"))
	Props.Counter(kitchen, At(40, y, 48.7, "S"), 6, { trim = false, color = Color3.fromRGB(150, 150, 150), material = M.Metal, top = Color3.fromRGB(170, 170, 170), topMaterial = M.Metal })
	Props.Counter(kitchen, At(32, y, 35, "S"), 10, { trim = false, color = Color3.fromRGB(150, 150, 150), material = M.Metal, top = Color3.fromRGB(170, 170, 170), topMaterial = M.Metal })
	for i = 0, 4 do
		D(kitchen, Vector3.new(1.2, 0.1, 1.2), CFrame.new(28 + i * 2, y + 9, 35) * CFrame.Angles(0, 0, math.rad(80)), C.Charcoal, M.Metal)
	end
	D(kitchen, Vector3.new(11, 0.2, 0.2), CFrame.new(32, y + 9.8, 35), C.Charcoal, M.Metal)
	Hiding.Add(Props.Locker(kitchen, At(21.6, y, 24, "E")))
	Props.BloodStain(kitchen, V(34, y, 30), 2, 33)
	D(kitchen, Vector3.new(0.2, 0.1, 1.4), CFrame.new(33, y + 3.75, 35.3) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(200, 200, 205), M.Metal)
	Pickups.Add(kitchen, CFrame.new(30, y + 3.72, 35.5), "Battery")
	Props.Pendant(kitchen, V(32, y + 15, 30), "G", { color = C.ColdBlue, brightness = 0.9 })
	wp("G", 32, 28)
	wp("G", 32, 42)

	------------------------------------------------------------------ BASEMENT STAIRS
	local stairs = Build.Folder(g, "BasementStairs")
	for i = 0, 27 do
		local top = y - 0.5 * (i + 1)
		local h = top - Y.B
		P(stairs, Vector3.new(1, h, 9.2), CFrame.new(26.5 + i, Y.B + h / 2, -45), Color3.fromRGB(66, 64, 62), M.Concrete, { name = "Step" })
	end
	P(stairs, Vector3.new(6, 13, 10), CFrame.new(23, Y.B + 6.4, -45), Color3.fromRGB(60, 60, 60), M.Concrete) -- solid under the landing
	D(stairs, Vector3.new(28, 0.3, 0.3), CFrame.new(40, y - 4, -40.6) * CFrame.Angles(0, 0, math.atan(0.5)), C.Rust, M.Metal)
	Props.CageLamp(stairs, V(38, y + 15, -45), "G", { brightness = 0.6 })
	Props.CageLamp(stairs, V(57, Y.B + 13, -45), "B", { brightness = 0.8 })
	Props.WallText(stairs, At(40, y - 2, -49.3, "N"), 10, 2.5, "لا تنزل")
end

----------------------------------------------------------------------------------------
-- FIRST FLOOR
----------------------------------------------------------------------------------------

local function corridor(parent, floor: string, faulty: boolean)
	local y = Y[floor]
	for x = -50, 50, 20 do
		local lamp = Props.Pendant(parent, V(x, y + 15, 0), floor, {
			brightness = floor == "F3" and 0.7 or 1,
			color = floor == "F3" and C.ColdBlue or nil,
			drop = 1.5,
		})
		if faulty or x == 30 then
			for _, d in lamp:GetDescendants() do
				if d:IsA("Light") then
					d:SetAttribute("Faulty", true)
				end
			end
		end
	end
	for x = -55, 55, 10 do
		wp(floor, x, 0)
	end
	wp(floor, 0, 18)
	wp(floor, 0, 30)
	Props.Rug(parent, At(0, y, 0, "N"), 116, 6, floor == "F3" and Color3.fromRGB(56, 40, 38) or C.DeepBurgundy, floor == "F3" and Color3.fromRGB(80, 70, 50) or C.DimGold)
	Props.Rug(parent, At(0, y, 20, "N"), 5, 26, floor == "F3" and Color3.fromRGB(56, 40, 38) or C.DeepBurgundy, floor == "F3" and Color3.fromRGB(80, 70, 50) or C.DimGold)
	concierge(floor, -57, 0, "E")
	concierge(floor, 57, 0, "W")
	concierge(floor, 0, 33, "S")
	Run.SetPoint(floor .. "Hall", CFrame.new(0, y + 3, 22))
end

local function firstFloor(parent)
	local f = Build.Folder(parent, "FirstFloor")
	local y = Y.F1
	exteriorWindows(f, "F1", {
		S = { { c = -45, w = 4, h = 7, b = 3 }, { c = -25, w = 4, h = 7, b = 3 }, { c = -5, w = 4, h = 7, b = 3 }, { c = 15, w = 4, h = 7, b = 3 }, { c = 35, w = 4, h = 7, b = 3 }, { c = 55, w = 4, h = 7, b = 3 } },
		N = { { c = -40, w = 4, h = 7, b = 3 }, { c = -12, w = 4, h = 7, b = 3 }, { c = 12, w = 4, h = 7, b = 3 }, { c = 38, w = 4, h = 7, b = 3 }, { c = 52, w = 4, h = 7, b = 3 } },
		E = { { c = -12, w = 4, h = 7, b = 3 }, { c = 0, w = 4, h = 7, b = 3 }, { c = 20, w = 4, h = 7, b = 3 }, { c = 40, w = 4, h = 7, b = 3 } },
		W = { { c = -12, w = 4, h = 7, b = 3 }, { c = 0, w = 4, h = 7, b = 3 }, { c = 16, w = 4, h = 7, b = 3 }, { c = 36, w = 4, h = 7, b = 3 } },
	})
	wall(f, "F1", -60, -6, 60, -6, { door(-50), door(-30), door(-10), door(10), door(30), door(50) })
	for _, x in { -40, -20, 0, 20, 40 } do
		wall(f, "F1", x, -50, x, -6)
	end
	wall(f, "F1", -60, 6, -8, 6, { door(-45), door(-19) })
	wall(f, "F1", 8, 6, 60, 6, { door(19), door(45) })
	wall(f, "F1", -8, 6, -8, 50, { door(38) })
	wall(f, "F1", 8, 6, 8, 50, { door(38) })
	wall(f, "F1", -60, 26, -30, 26, { door(-45) })
	wall(f, "F1", -30, 26, -8, 26)
	wall(f, "F1", 8, 26, 30, 26)
	wall(f, "F1", -30, 6, -30, 50)
	wall(f, "F1", 30, 6, 30, 50)

	finish(f, { -60, -6, 60, 6 }, "F1", Color3.fromRGB(60, 18, 24), M.Carpet)
	finish(f, { -8, 6, 8, 50 }, "F1", Color3.fromRGB(60, 18, 24), M.Carpet)
	finish(f, { -60, -50, 60, -6 }, "F1", Color3.fromRGB(80, 54, 40), M.WoodPlanks)
	finish(f, { -60, 6, -30, 26 }, "F1", Color3.fromRGB(110, 106, 100), M.CeramicTiles)
	finish(f, { -60, 26, -30, 50 }, "F1", Color3.fromRGB(110, 106, 100), M.CeramicTiles)
	finish(f, { -30, 6, -8, 26 }, "F1", Color3.fromRGB(150, 146, 140), M.CeramicTiles)
	finish(f, { -30, 26, -8, 50 }, "F1", Color3.fromRGB(80, 54, 40), M.WoodPlanks)
	finish(f, { 8, 6, 60, 50 }, "F1", Color3.fromRGB(80, 54, 40), M.WoodPlanks)

	local hall = Build.Folder(f, "Corridor")
	corridor(hall, "F1", false)
	Props.Painting(hall, At(-25, y + 7, 5.55, "S"), 5, 3.5, "hotel", 12)
	Props.Painting(hall, At(30, y + 7, -5.55, "N"), 3.5, 4.5, "portrait", 13)
	Props.Plant(hall, CFrame.new(-57, y, -4), { seed = 8 })
	Props.Wheelchair(hall, At(52, y, 3, "W"))
	Props.Cart(hall, At(-35, y, 3.6, "E"))

	-- guest rooms 101-106 (south)
	for i, cx in { -50, -30, -10, 10, 30, 50 } do
		local number = tostring(100 + i)
		local rooms = Build.Folder(f, "Room" .. number)
		bedroom(rooms, "F1", cx, -28, V(0, 0, 1), 20, 44, { messy = i == 4, faulty = i == 2 })
		Doors.Add(f, { id = "Room" .. number, cf = At(cx, y, -6, "N"), number = number, style = "room", locked = i == 3, lockedText = "لافتة «الرجاء عدم الإزعاج». شيء ما يخدش من الجهة الأخرى." })
		roomSign(f, At(cx + 3.4, y + 7, -5.55, "N"), number)
	end
	-- 107, 108, 109 (north)
	for _, spec in { { "107", -19, 38, V(1, 0, 0), 24, 22, -8, 38, "W" }, { "108", 19, 16, V(0, 0, -1), 22, 20, 19, 6, "N" }, { "109", 19, 38, V(-1, 0, 0), 24, 22, 8, 38, "E" } } do
		local number, cx, cz, fwd, W, Dp, dx, dz = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7], spec[8]
		local rooms = Build.Folder(f, "Room" .. number)
		bedroom(rooms, "F1", cx, cz, fwd, W, Dp, {})
		local facing = (fwd.X > 0 and "E") or (fwd.X < 0 and "W") or "S"
		Doors.Add(f, { id = "Room" .. number, cf = At(dx, y, dz, facing), number = number, style = "room" })
	end
	roomSign(f, At(-7.55, y + 7, 34.6, "E"), "107")
	roomSign(f, At(7.55, y + 7, 34.6, "W"), "109")
	roomSign(f, At(22.4, y + 7, 5.55, "S"), "108")

	-- housekeeping
	local hk = Build.Folder(f, "Housekeeping")
	Props.Shelf(hk, At(-45, y, 24.9, "S"), { width = 10, fill = "linen", seed = 61 })
	Props.Shelf(hk, At(-58.9, y, 16, "E"), { width = 8, fill = "linen", seed = 62 })
	Props.Cart(hk, At(-40, y, 12, "E"))
	Props.Cart(hk, At(-36, y, 18, "S"))
	Hiding.Add(Props.Locker(hk, At(-31.6, y, 14, "W")))
	Hiding.Add(Props.Locker(hk, At(-31.6, y, 18, "W")))
	Pickups.Add(hk, CFrame.new(-40, y + 3.55, 12), "Battery")
	Props.Pendant(hk, V(-45, y + 15, 16), "F1", { color = C.ColdBlue })
	Doors.Add(f, { id = "HousekeepingDoor", cf = At(-45, y, 6, "S"), w = 4.5, style = "wood", label = "التدبير المنزلي" })
	wp("F1", -45, 16)

	-- laundry + hidden passage
	local laundry = Build.Folder(f, "Laundry")
	for i = 0, 3 do
		Props.WashingMachine(laundry, At(-50 + i * 3.4, y, 48.3, "S"))
	end
	for i = 0, 2 do
		Props.HangingSheet(laundry, At(-44 + i * 4, y + 10, 36, "E") * CFrame.Angles(0, math.rad(90), 0), 6, 7)
	end
	Props.Counter(laundry, At(-36, y, 30, "N"), 8, { trim = false, color = C.Walnut, top = C.Bone, topMaterial = M.Fabric })
	Pickups.Document(laundry, CFrame.new(-35, y + 3.72, 30.3), "housekeeping_rhyme")
	Props.Pendant(laundry, V(-45, y + 15, 38), "F1", { color = C.ColdBlue, brightness = 0.8 })
	Doors.Add(f, { id = "LaundryDoor", cf = At(-45, y, 26, "S"), w = 4.5, style = "wood", label = "غرفة الغسيل" })
	-- passage enclosure X[-59.6,-55] Z[45,49.6]
	Build.Wall(laundry, -55, 44.8, -55, 50, y, 15, STYLE.F1)
	Build.Wall(laundry, -60, 45, -55, 45, y, 15, STYLE.F1, { { c = -57.5, w = 3.2, h = 7.5 } })
	local panel = P(laundry, Vector3.new(3.2, 7.5, 0.5), CFrame.new(-57.5, y + 3.75, 45), STYLE.F1.color, M.Fabric, { name = "LoosePanel" })
	D(laundry, Vector3.new(3.4, 0.3, 0.6), CFrame.new(-57.5, y + 7.4, 44.9), C.Walnut, M.Wood)
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, 18, 2)
	truss.CFrame = CFrame.new(-57.5, y + 9, 48.5)
	truss.Color = C.Rust
	truss.Material = M.CorrodedMetal
	truss.Parent = laundry
	local panelPrompt
	panelPrompt = Interact.Add(panel, { text = "اخلع", object = "لوح جدار مخلخل", hold = 1.5, dist = 7, los = false }, function(player)
		if not panel.Parent then
			return
		end
		panelPrompt.Enabled = false
		panel.Anchored = false
		panel.CanCollide = false
		panel.CollisionGroup = "Debris"
		task.delay(3, function()
			panel:Destroy()
		end)
		Run.Notify(player, "يسقط اللوح. سلّم يصعد في الظلام.", "info")
		Run.SetFlag("passage", true)
	end)
	Hotel.Refs.LoosePanel = panel
	wp("F1", -45, 36)

	-- bathrooms
	local bath = Build.Folder(f, "Bathrooms")
	for i = 0, 2 do
		local x = -28 + i * 4
		Build.Wall(bath, x - 2, 26, x - 2, 20, y, 8, { color = Color3.fromRGB(150, 140, 130), material = M.Marble, thickness = 0.3 })
		Props.Toilet(bath, At(x, y, 24.6, "S"))
	end
	Build.Wall(bath, -18, 26, -18, 20, y, 8, { color = Color3.fromRGB(150, 140, 130), material = M.Marble, thickness = 0.3 })
	for i, x in { -26, -20, -14 } do
		Props.Sink(bath, At(x, y, 7.6, "N"), { blood = i == 2 })
		Props.Mirror(bath, At(x, y + 6.2, 6.45, "N"), 3, 3, { broken = i ~= 2, text = i == 2 and "لا تنظر" or nil, seed = i })
	end
	Props.Pendant(bath, V(-19, y + 15, 16), "F1", { color = C.ColdBlue, brightness = 0.7 })
	Doors.Add(f, { id = "BathroomDoor", cf = At(-19, y, 6, "S"), w = 4.5, style = "wood", label = "دورات المياه" })
	wp("F1", -19, 14)

	-- staff quarters
	local staff = Build.Folder(f, "StaffQuarters")
	for i, z in { 16, 30, 44 } do
		Hiding.Add(Props.Bed(staff, At(54.4, y, z, "W"), { single = true, blanket = Color3.fromRGB(60, 60, 70) }))
		Hiding.Add(Props.Locker(staff, At(31.6, y, z, "E")))
		if i == 2 then
			Props.BloodStain(staff, V(50, y, z), 2, 71)
		end
	end
	Props.DiningTable(staff, At(44, y, 30, "N"), { width = 4, length = 8, seats = 2, candles = false, cloth = Color3.fromRGB(150, 140, 120) })
	Pickups.Add(staff, CFrame.new(44, y + 3.27, 28), "Bandage")
	Pickups.Add(staff, CFrame.new(43, y + 3.27, 32), "Battery")
	Props.Pendant(staff, V(45, y + 15, 28), "F1", { brightness = 0.8 })
	Doors.Add(f, { id = "StaffDoor", cf = At(45, y, 6, "S"), w = 4.5, style = "wood", label = "سكن الموظفين" })
	wp("F1", 45, 20)
	wp("F1", 45, 40)
end

----------------------------------------------------------------------------------------
-- SECOND FLOOR
----------------------------------------------------------------------------------------

local function suite(parent, cx: number, number: string, opts)
	local y = Y.F2
	local s = Build.Folder(parent, "Suite" .. number)
	-- bedroom (back) / living (front) partition
	wall(s, "F2", cx - 20, -28, cx + 20, -28, { door(cx, 6, 10) })
	local bed = Props.Bed(s, At(cx, y, -43.8, "N"), { blanket = C.DeepBurgundy, panel = C.Gold })
	Hiding.Add(bed)
	Props.Nightstand(s, At(cx - 5, y, -47.4, "N"), "F2")
	Props.Nightstand(s, At(cx + 5, y, -47.4, "N"), nil)
	Hiding.Add(Props.Wardrobe(s, At(cx - 17.8, y, -40, "E")))
	Props.Desk(s, At(cx + 18.3, y, -38, "E"), { width = 5 })
	Props.Mirror(s, At(cx + 19.55, y + 6.5, -42, "W"), 3, 4, { broken = opts.broken })
	Props.Chandelier(s, V(cx, y + 15, -39), "F2", { arms = 6, radius = 1.8, brightness = 1 })
	Props.Painting(s, At(cx, y + 9.5, -49.35, "N"), 7, 3.5, "hotel", math.floor(cx))
	Props.Rug(s, At(cx, y, -38, "N"), 14, 10, C.DeepBurgundy)
	-- living area
	Props.Sofa(s, At(cx - 14, y, -17, "E"), { width = 8 })
	Props.CoffeeTable(s, At(cx - 10, y, -17, "E"))
	Props.Armchair(s, At(cx - 6, y, -17, "W"))
	if opts.piano then
		Props.Piano(s, At(cx + 11, y, -19, "S"))
	else
		Props.DiningTable(s, At(cx + 11, y, -16, "N"), { width = 3.5, length = 4, seats = 1, cloth = C.Bone })
	end
	Props.Chandelier(s, V(cx, y + 15, -17), "F2", { arms = 6, radius = 1.8, brightness = 1 })
	Props.Painting(s, At(cx - 19.55, y + 7.5, -16, "E"), 4, 5, "portrait", math.floor(cx) + 5)
	Props.Plant(s, CFrame.new(cx + 17, y, -9), { seed = math.floor(cx) })
	Props.Dust(s, V(cx, y + 7, -28), Vector3.new(36, 10, 40))
	wp("F2", cx, -16)
	wp("F2", cx, -38)
	Doors.Add(parent, { id = "Suite" .. number, cf = At(cx, y, -6, "N"), number = number, style = "room", w = 4.5 })
	roomSign(parent, At(cx + 3.4, y + 7, -5.55, "N"), number)
	return s
end

local function secondFloor(parent)
	local f = Build.Folder(parent, "SecondFloor")
	local y = Y.F2
	exteriorWindows(f, "F2", {
		S = { { c = -48, w = 5, h = 9, b = 2 }, { c = -32, w = 5, h = 9, b = 2 }, { c = -8, w = 5, h = 9, b = 2 }, { c = 8, w = 5, h = 9, b = 2 }, { c = 32, w = 5, h = 9, b = 2 }, { c = 48, w = 5, h = 9, b = 2 } },
		N = { { c = 50, w = 4, h = 7, b = 3 } },
		E = { { c = -40, w = 4, h = 7, b = 3 }, { c = -16, w = 4, h = 7, b = 3 }, { c = 0, w = 4, h = 7, b = 3 }, { c = 20, w = 4, h = 7, b = 3 }, { c = 40, w = 4, h = 7, b = 3 } },
		W = { { c = -40, w = 4, h = 7, b = 3 }, { c = -16, w = 4, h = 7, b = 3 }, { c = 0, w = 4, h = 7, b = 3 }, { c = 16, w = 4, h = 7, b = 3 } },
	}, { curtain = C.DeepBurgundy })
	wall(f, "F2", -60, -6, 60, -6, { door(-40), door(0), door(40) })
	wall(f, "F2", -20, -50, -20, -6)
	wall(f, "F2", 20, -50, 20, -6)
	wall(f, "F2", -60, 6, -8, 6, { door(-34, 6, 10) })
	wall(f, "F2", 8, 6, 60, 6, { door(24), door(50) })
	wall(f, "F2", -8, 6, -8, 50, { door(38) })
	wall(f, "F2", 8, 6, 8, 50)
	wall(f, "F2", -60, 26, -8, 26)
	wall(f, "F2", 8, 30, 40, 30, { door(24, 4) })
	wall(f, "F2", 40, 6, 40, 50)

	local hole = { { -59, 45, -55, 49 } }
	finish(f, { -60, -6, 60, 6 }, "F2", Color3.fromRGB(26, 40, 32), M.Carpet)
	finish(f, { -8, 6, 8, 50 }, "F2", Color3.fromRGB(26, 40, 32), M.Carpet)
	finish(f, { -60, -50, 60, -6 }, "F2", Color3.fromRGB(70, 22, 30), M.Carpet)
	finish(f, { -60, 6, -8, 26 }, "F2", Color3.fromRGB(70, 46, 32), M.Wood)
	finish(f, { -60, 26, -8, 50 }, "F2", Color3.fromRGB(64, 42, 30), M.WoodPlanks, hole)
	finish(f, { 8, 6, 40, 30 }, "F2", Color3.fromRGB(54, 20, 26), M.Carpet)
	finish(f, { 8, 30, 40, 50 }, "F2", Color3.fromRGB(40, 30, 26), M.WoodPlanks)
	finish(f, { 40, 6, 60, 50 }, "F2", Color3.fromRGB(70, 46, 32), M.Wood)

	local hall = Build.Folder(f, "Corridor")
	corridor(hall, "F2", false)
	for x = -45, 45, 30 do
		Props.Sconce(hall, At(x, y + 7.5, 5.55, "S"), "F2")
	end
	Props.GrandfatherClock(hall, At(-58.9, y, 3, "E"))

	suite(f, -40, "201", {})
	suite(f, 0, "202", { piano = true })
	suite(f, 40, "203", { broken = true })
	Pickups.Document(f, CFrame.new(44.6, y + 2.42, -47.2), "suite_diary")
	Pickups.Add(f, CFrame.new(36, y + 2.42, -47.4), "Bandage")
	Props.Doll(f, At(40, y + 4.3, -45, "N"))
	Props.WallText(f, At(59.35, y + 7, -36, "W"), 8, 2.4, "صه... الأطفال نائمون")
	Run.Zones.Suite203 = {
		min = V(20.5, y - 1, -49.5),
		max = V(59.5, y + 12, -28.6),
		lair = At(57, y, -48, "N"),
		warning = "اخرج... الأطفال نائمون هنا.",
	}

	-- conference room
	local conf = Build.Folder(f, "Conference")
	Props.DiningTable(conf, At(-34, y, 16, "E") * CFrame.Angles(0, 0, 0), { width = 5, length = 24, seats = 6, cloth = C.DarkBrown })
	D(conf, Vector3.new(0.3, 7, 12), CFrame.new(-59.5, y + 7, 16), C.Bone, M.Fabric)
	Build.Text(conf, Vector3.new(10, 5, 0.1), At(-59.3, y + 7.5, 16, "E"), "الربع الرابع 1973\nنسبة الإشغال ... 100%\nضيوف غادروا ... 0", { bgTransparency = 1, color = Color3.fromRGB(40, 40, 50), font = Enum.Font.SpecialElite })
	for _, x in { -46, -22 } do
		Props.Chandelier(conf, V(x, y + 15, 16), "F2", { arms = 6, brightness = 1 })
	end
	Props.Painting(conf, At(-30, y + 8, 25.55, "S"), 6, 4, "eyes", 81)
	Doors.Add(f, { id = "ConferenceDoor", cf = At(-34, y, 6, "S"), w = 6, h = 10, style = "wood", double = true, label = "قاعة الاجتماعات" })
	wp("F2", -34, 12)
	wp("F2", -50, 20)

	-- library (barricaded from inside; reached through the laundry passage)
	local lib = Build.Folder(f, "Library")
	for i, x in { -46, -38, -30, -22, -14 } do
		Props.Shelf(lib, At(x, y, 48.9, "S"), { width = 7.5, height = 12, rows = 6, seed = 90 + i })
	end
	for i, x in { -54, -44, -20, -12 } do
		Props.Shelf(lib, At(x, y, 27.1, "N"), { width = 7, height = 12, rows = 6, seed = 100 + i })
	end
	Props.Shelf(lib, At(-34, y, 27.1, "N"), { width = 6, height = 5, rows = 2, fill = false })
	Puzzles.Books(lib, At(-34, y + 3.6, 27.6, "N"), function(player)
		Run.Notify(nil, "شيء ما ينقر تحت الرف. ينفتح درج مخفي.", "info")
		Pickups.Document(lib, CFrame.new(-34, y + 0.32, 27.4), "journal_1")
		Run.SetFlag("books", true)
	end)
	Props.Desk(lib, At(-36, y, 38, "S"), { width = 6, lamp = true, zone = "F2" })
	Props.Desk(lib, At(-22, y, 38, "S"), { width = 6, lamp = true, zone = "F2" })
	Props.Armchair(lib, At(-50, y, 36, "E"))
	Hiding.Add(Props.Wardrobe(lib, At(-9.8, y, 32.6, "W")))
	Props.Chandelier(lib, V(-34, y + 15, 38), "F2", { brightness = 0.9 })
	-- railing around the passage hole
	D(lib, Vector3.new(4.6, 3, 0.3), CFrame.new(-57, y + 1.5, 44.8), C.Walnut, M.Wood)
	Props.Dust(lib, V(-34, y + 7, 38), Vector3.new(48, 10, 22))
	Doors.Add(f, { id = "LibraryDoor", cf = At(-8, y, 38, "E"), w = 4.5, style = "wood", label = "المكتبة", barricaded = true })
	local inside = Interact.Anchor(lib, V(-9.6, y + 4.5, 38), "BarricadeAnchor")
	local barricadePrompt
	barricadePrompt = Interact.Add(inside, { text = "انزع الألواح", object = "الحاجز", hold = 2, dist = 7 }, function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or root.Position.X > -8 then
			return -- only from inside the library
		end
		barricadePrompt.Enabled = false
		Doors.RemoveBarricade("LibraryDoor")
		Doors.SetOpen("LibraryDoor", true, player)
		Run.SetFlag("libraryOpen", true)
	end)
	Hotel.Refs.BarricadePrompt = barricadePrompt
	wp("F2", -34, 34)
	wp("F2", -50, 42)

	-- manager's office
	local mgr = Build.Folder(f, "ManagerOffice")
	Props.Desk(mgr, At(24, y, 20, "S"), { width = 7, lamp = true, zone = "F2", chair = true })
	Pickups.Document(mgr, CFrame.new(22, y + 3.17, 19.6), "manager_photo")
	Props.Armchair(mgr, At(21, y, 13, "N"))
	Props.Armchair(mgr, At(27, y, 13, "N"))
	Props.Rug(mgr, At(24, y, 18, "N"), 14, 12, C.DeepBurgundy)
	Props.GrandfatherClock(mgr, At(9.4, y, 26, "E"))
	Props.Chandelier(mgr, V(24, y + 15, 18), "F2", { brightness = 1 })
	-- safe with keypad (Journal I tells you the code is Lina's birthday)
	local safe = Build.Model(mgr, "Safe")
	P(safe, Vector3.new(3, 3.6, 3), CFrame.new(10, y + 1.8, 14), C.Charcoal, M.Metal)
	local safeDoor = P(safe, Vector3.new(0.3, 3, 2.6), CFrame.new(11.65, y + 1.8, 14), Color3.fromRGB(60, 60, 64), M.Metal, { name = "SafeDoor" })
	Build.Cyl(safe, 0.9, 0.2, CFrame.new(11.85, y + 2.2, 14) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), C.Gold, M.Metal, { decor = true })
	Puzzles.Keypad(safe, At(8.45, y + 5.4, 14, "E"), {
		id = "ManagerSafe",
		code = Config.Codes.ManagerSafe,
		title = "خزنة المدير",
		onSolved = function()
			safeDoor.CFrame = CFrame.new(11.8, y + 1.8, 15.4) * CFrame.Angles(0, math.rad(-80), 0)
			Pickups.Add(mgr, CFrame.new(10.2, y + 3.62, 14), "Key307")
			Run.SetFlag("safeOpen", true)
		end,
	})
	-- sliding bookcase hiding the secret room
	local bookcase = Props.Shelf(mgr, At(24, y, 28.9, "S"), { width = 5.4, height = 11, rows = 5, seed = 120 })
	bookcase.PrimaryPart = bookcase:FindFirstChildWhichIsA("BasePart")
	Puzzles.SlidingBookcase(bookcase, V(5.6, 0, 0), "secretRoom")
	local crooked = Props.Painting(mgr, At(39.55, y + 6.5, 18, "W") * CFrame.Angles(0, 0, math.rad(9)), 4, 5, "portrait", 130)
	Puzzles.Switch(crooked:FindFirstChild("Canvas"), "عدّلها", "لوحة مائلة", "secretRoom", "شيء ثقيل ينزلق خلف خزانة الكتب...")
	Doors.Add(f, { id = "ManagerDoor", cf = At(24, y, 6, "S"), w = 4.5, style = "room", label = "مكتب المدير" })
	Build.Text(f, Vector3.new(3, 0.7, 0.1), At(28.2, y + 7, 5.55, "S"), "المدير", { bg = C.Black, color = C.Gold })
	wp("F2", 24, 12)

	-- secret room: ritual chamber
	local secret = Build.Folder(f, "SecretRoom")
	Build.Text(secret, Vector3.new(14, 14, 0.05), CFrame.new(24, y + 0.04, 41) * CFrame.Angles(math.rad(-90), 0, 0), "◯", {
		bgTransparency = 1,
		color = C.Blood,
		font = Enum.Font.Arial,
		name = "RitualCircle",
	})
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Props.Candle(secret, V(24 + math.cos(a) * 5.5, y, 41 + math.sin(a) * 5.5), { light = i % 2 == 0, range = 9 })
	end
	P(secret, Vector3.new(5, 3, 2.5), CFrame.new(24, y + 1.5, 47.8), C.Black, M.Slate)
	Pickups.Document(secret, CFrame.new(24, y + 3.02, 47.6), "journal_2")
	for i = 0, 11 do
		Props.Painting(secret, At(9.55, y + 4 + (i % 3) * 2.8, 33 + math.floor(i / 3) * 4, "E"), 1.6, 2, i % 4 == 0 and "eyes" or "portrait", 200 + i)
	end
	Props.WallText(secret, At(39.55, y + 7, 40, "W"), 12, 3, "كل ضيف يبقى")
	Props.BloodStain(secret, V(24, y, 37), 3, 201)
	Props.Mirror(secret, At(39.55, y + 6, 34, "W"), 3, 4.5, { broken = true, seed = 9 })
	wp("F2", 24, 40)

	-- archive
	local archive = Build.Folder(f, "Archive")
	for i, z in { 14, 24, 34, 44 } do
		Props.Shelf(archive, At(58.9, y, z, "W"), { width = 8, fill = "boxes", seed = 140 + i })
	end
	Props.Desk(archive, At(46, y, 30, "E"), { width = 5, lamp = true, zone = "F2" })
	Hiding.Add(Props.Wardrobe(archive, At(41.8, y, 44, "E")))
	Pickups.Add(archive, CFrame.new(44.6, y + 3.17, 30.4), "Battery")
	Pickups.Add(archive, CFrame.new(50, y, 12), "Bandage")
	Props.Pendant(archive, V(50, y + 15, 28), "F2", { brightness = 0.7 })
	Doors.Add(f, { id = "ArchiveDoor", cf = At(50, y, 6, "S"), w = 4.5, style = "wood", label = "الأرشيف" })
	wp("F2", 50, 20)
	wp("F2", 50, 40)
end

----------------------------------------------------------------------------------------
-- THIRD FLOOR
----------------------------------------------------------------------------------------

local function thirdFloor(parent)
	local f = Build.Folder(parent, "ThirdFloor")
	local y = Y.F3
	exteriorWindows(f, "F3", {
		S = { { c = -45, w = 4, h = 7, b = 3 }, { c = -25, w = 4, h = 7, b = 3, broken = true }, { c = -5, w = 4, h = 7, b = 3 }, { c = 15, w = 4, h = 7, b = 3, broken = true }, { c = 35, w = 4, h = 7, b = 3 }, { c = 55, w = 4, h = 7, b = 3 } },
		N = { { c = -50, w = 4, h = 7, b = 3 }, { c = -36, w = 4, h = 7, b = 3, broken = true }, { c = -22, w = 4, h = 7, b = 3 }, { c = 50, w = 4, h = 7, b = 3 } },
		E = { { c = -12, w = 4, h = 7, b = 3 }, { c = 0, w = 4, h = 7, b = 3, broken = true }, { c = 20, w = 4, h = 7, b = 3 }, { c = 40, w = 4, h = 7, b = 3 } },
		W = { { c = -12, w = 4, h = 7, b = 3 }, { c = 0, w = 4, h = 7, b = 3 }, { c = 16, w = 4, h = 7, b = 3 }, { c = 36, w = 4, h = 7, b = 3 } },
	}, { curtain = Color3.fromRGB(70, 66, 64) })
	wall(f, "F3", -60, -6, 60, -6, { door(-50), door(-30), door(-10), door(10), door(30), door(50) })
	for _, x in { -40, -20, 0, 20, 40 } do
		wall(f, "F3", x, -50, x, -6)
	end
	wall(f, "F3", -60, 6, -8, 6, { door(-34, 8, 11) })
	wall(f, "F3", 8, 6, 60, 6, { door(24), door(50) })
	wall(f, "F3", -8, 6, -8, 50)
	wall(f, "F3", 8, 6, 8, 50)
	wall(f, "F3", 40, 6, 40, 50)
	-- 307 inner wall with the mirror cavity
	local mirrorWallParts = wall(f, "F3", 8, 30, 40, 30, { door(24, 4), { c = 34, w = 3.4, h = 4.4, b = 3.6 } })
	local backing = P(f, Vector3.new(3.4, 4.4, 0.8), CFrame.new(34, y + 5.8, 30), STYLE.F3.color, STYLE.F3.material, { name = "MirrorBacking" })
	Hotel.Refs.MirrorBacking = backing
	local _ = mirrorWallParts

	finish(f, { -60, -6, 60, 6 }, "F3", Color3.fromRGB(46, 36, 32), M.WoodPlanks)
	finish(f, { -8, 6, 8, 50 }, "F3", Color3.fromRGB(46, 36, 32), M.WoodPlanks)
	finish(f, { -60, -50, 60, -6 }, "F3", Color3.fromRGB(56, 46, 40), M.WoodPlanks)
	finish(f, { -60, 6, -8, 50 }, "F3", Color3.fromRGB(40, 34, 30), M.WoodPlanks)
	finish(f, { 8, 6, 60, 50 }, "F3", Color3.fromRGB(60, 40, 40), M.Carpet)

	-- the haunted corridor
	local hall = Build.Folder(f, "HauntedCorridor")
	corridor(hall, "F3", true)
	Props.WallText(hall, At(-20, y + 7, 5.55, "S"), 14, 3, "إنه يسمعك")
	Props.WallText(hall, At(36, y + 6, -5.55, "N"), 10, 3, "307 307 307 307")
	Props.WallText(hall, At(-59.5, y + 6.5, 0, "E"), 6, 3, "غادِر", { font = Enum.Font.Arial })
	for i, x in { -44, -12, 18, 44 } do
		Props.HandPrint(hall, At(x, y + 3 + i % 2, i % 2 == 0 and 5.55 or -5.55, i % 2 == 0 and "S" or "N"))
	end
	Props.DragMarks(hall, V(-40, y, 0), V(-34, y, 6))
	Props.BloodStain(hall, V(-34, y, 2), 2.4, 301)
	Props.Doll(hall, At(14, y, 2, "W"))
	Props.Wheelchair(hall, At(-52, y, -2, "E"))
	Props.Debris(hall, V(28, y, 0), 6, 302)
	Hotel.Refs.F3FarEnd = V(-55, y, 0)

	-- abandoned rooms 301-306
	for i, cx in { -50, -30, -10, 10, 30, 50 } do
		local number = tostring(300 + i)
		local room = Build.Folder(f, "Room" .. number)
		bedroom(room, "F3", cx, -28, V(0, 0, 1), 20, 44, { messy = true, painting = i % 2 == 0 and "eyes" or "symbol" })
		Doors.Add(f, {
			id = "Room" .. number,
			cf = At(cx, y, -6, "N"),
			number = number,
			style = "rotten",
			locked = i == 3 or i == 5,
			lockedText = "المقبض لا يدور. شيء ما يتنفّس في الجهة الأخرى.",
		})
		roomSign(f, At(cx + 3.4, y + 7, -5.55, "N"), number)
	end
	Pickups.Add(f, CFrame.new(-50, y, -14), "Battery")
	Pickups.Add(f, CFrame.new(30, y, -14), "Bandage")

	-- collapsed ballroom (encounter area)
	local ball = Build.Folder(f, "Ballroom")
	for _, pos in { V(-48, y, 18), V(-20, y, 18), V(-48, y, 38), V(-20, y, 38) } do
		Props.Column(ball, pos, 15, { color = Color3.fromRGB(70, 66, 64) })
	end
	local fallen = Props.Chandelier(ball, V(-34, y + 3.2, 28), "F3", { drop = 0.1, brightness = 0.4 })
	fallen:PivotTo(fallen:GetPivot() * CFrame.Angles(math.rad(20), 0, math.rad(15)))
	Props.Debris(ball, V(-34, y, 28), 16, 311)
	Props.Debris(ball, V(-52, y, 12), 10, 312)
	for i, pos in { V(-42, y, 14), V(-26, y, 22), V(-44, y, 32), V(-24, y, 34) } do
		Props.DiningTable(ball, At(pos.X, y, pos.Z, i % 2 == 0 and "E" or "N"), { width = 4, length = 4, seats = 1, candles = false, cloth = Color3.fromRGB(120, 110, 96), fallenChair = 1 })
	end
	P(ball, Vector3.new(30, 2, 7), CFrame.new(-34, y + 1, 46.4), C.Walnut, M.WoodPlanks) -- stage
	for _, x in { -46, -22 } do
		D(ball, Vector3.new(6, 13, 0.6), CFrame.new(x, y + 8.5, 47), C.DeepBurgundy, M.Fabric)
	end
	Props.Piano(ball, At(-30, y + 2, 45.4, "S"))
	Hiding.Add(Props.Wardrobe(ball, At(-58.2, y, 26, "E")))
	Hiding.Add(Props.Wardrobe(ball, At(-9.8, y, 20, "W")))
	Hiding.Add(Props.Wardrobe(ball, At(-9.8, y, 40, "W")))
	Props.WallText(ball, At(-34, y + 10, 49.35, "S"), 16, 3, "الحفلة لا تنتهي أبدًا")
	for _, pos in { V(-50, y + 15, 30), V(-18, y + 15, 26) } do
		local lamp = Props.Pendant(ball, pos, "F3", { color = C.ColdBlue, brightness = 0.6 })
		for _, d in lamp:GetDescendants() do
			if d:IsA("Light") then
				d:SetAttribute("Faulty", true)
			end
		end
	end
	Props.Dust(ball, V(-34, y + 7, 28), Vector3.new(48, 12, 40))
	for _, p in { { -34, 12 }, { -50, 22 }, { -18, 30 }, { -40, 40 }, { -14, 12 } } do
		wp("F3", p[1], p[2])
	end
	Run.SetPoint("ShadowLair", CFrame.new(-34, y, 36))

	-- ROOM 307
	local r307 = Build.Folder(f, "Room307")
	Doors.Add(f, { id = "Room307", cf = At(24, y, 6, "S"), number = "307", style = "rotten", locked = true, key = "Key307", lockedText = "الغرفة 307. مقفلة. الرقم مخدوش بالأظافر." })
	roomSign(f, At(27.4, y + 7, 5.55, "S"), "307")
	Props.Sofa(r307, At(14, y, 16, "E"), { width = 7, torn = true, color = Color3.fromRGB(110, 60, 70) })
	Props.CoffeeTable(r307, At(18.5, y, 16, "E"))
	Props.Desk(r307, At(36.8, y, 14, "E"), { width = 5 })
	Pickups.Document(r307, CFrame.new(36.6, y + 3.17, 13.6), "journal_3")
	local mirrorCF = At(34, y + 5.8, 29.55, "S")
	local _, glass = Props.Mirror(r307, mirrorCF, 3, 4, {})
	Hotel.Refs.MirrorGlass = glass
	Hotel.Refs.MirrorFigure = At(34, y, 32.6, "S")
	Hotel.Refs.MirrorViewCF = CFrame.lookAt(V(34, y + 5.6, 22), V(34, y + 5.8, 30))
	local mirrorPrompt
	mirrorPrompt = Interact.Add(glass, { text = "انظر في", object = "المرآة", dist = 7, los = false, hold = 0.5 }, function(player)
		if Run.Flag("mirror") then
			return
		end
		mirrorPrompt.Enabled = false
		Hotel.Refs.MirrorUser = player
		Run.SetFlag("mirror", true)
	end)
	for i = 0, 5 do
		Props.Doll(r307, At(10 + i * 1.6, y, 28.6, "S"))
	end
	Props.WallText(r307, At(8.45, y + 7, 18, "E"), 14, 4, "لينا لينا لينا لينا", { color = Color3.fromRGB(90, 20, 20) })
	Props.Pendant(r307, V(24, y + 15, 18), "F3", { color = C.Warm, brightness = 0.6 })
	-- nursery
	local nursery = Build.Folder(r307, "Nursery")
	Hiding.Add(Props.Bed(nursery, At(24, y, 43.5, "S"), { single = true, blanket = Color3.fromRGB(200, 170, 180), sheet = C.Bone }))
	Pickups.Add(nursery, CFrame.new(24, y + 4.6, 46.8), "Locket", { hold = 1.2 })
	Props.MusicBox(nursery, At(16.4, y + 2.4, 47.2, "S"))
	Props.Nightstand(nursery, At(17, y, 47.4, "S"), nil)
	for i = 0, 4 do
		Props.Doll(nursery, At(32 + (i % 3) * 1.6, y, 46 - math.floor(i / 3) * 2, "W"))
	end
	Props.Chair(nursery, At(12, y, 36, "E"), { seat = Color3.fromRGB(200, 170, 180) })
	Props.Candle(nursery, V(30, y, 38))
	Props.Candle(nursery, V(18, y, 38))
	Props.WallText(nursery, At(39.55, y + 6, 40, "W"), 10, 3, "لا تأخذ قلادتها", { color = Color3.fromRGB(110, 20, 20) })
	Run.Zones.Nursery = {
		min = V(8.5, y - 1, 30.5),
		max = V(39.5, y + 12, 49.5),
		lair = At(38, y, 48, "W"),
		warning = "أعِدها... أعِدها!...",
	}
	wp("F3", 24, 16)

	-- ROOM 308 (opens by itself)
	local r308 = Build.Folder(f, "Room308")
	Doors.Add(f, { id = "Room308", cf = At(50, y, 6, "S"), number = "308", style = "rotten", locked = true, lockedText = "مقفل." })
	roomSign(f, At(53.4, y + 7, 5.55, "S"), "308")
	for i = 0, 5 do
		Props.Chair(r308, At(44 + (i % 3) * 5, y, 40 + math.floor(i / 3) * 4, "N"))
	end
	Props.WallText(r308, At(50, y + 7, 49.35, "S"), 16, 4, "إنها ما زالت هنا")
	Hiding.Add(Props.Bed(r308, At(55, y, 18, "W"), { messy = true, single = true }))
	Pickups.Add(r308, CFrame.new(46, y, 22), "Battery")
	Props.Candle(r308, V(50, y, 44))
	wp("F3", 50, 26)
end

----------------------------------------------------------------------------------------
-- BASEMENT
----------------------------------------------------------------------------------------

local function basement(parent)
	local b = Build.Folder(parent, "Basement")
	local y = Y.B
	local brick = { color = Color3.fromRGB(86, 54, 46), material = M.Brick }
	-- perimeter
	wall(b, "B", -60, -50, 60, -50, nil, brick)
	wall(b, "B", -60, 50, 60, 50, nil, brick)
	wall(b, "B", 60, -50, 60, 50, nil, brick)
	wall(b, "B", -60, -50, -60, 50, { door(-30, 6, 10) }, brick)
	-- rooms
	wall(b, "B", -60, -40, 52, -40)
	wall(b, "B", 52, -40, 52, 32, { door(-20, 5), door(15, 5) })
	wall(b, "B", 14, -2, 52, -2)
	wall(b, "B", 14, -40, 14, 32, { door(-20, 5) })
	wall(b, "B", -30, 32, 52, 32, { door(-8, 5) })
	wall(b, "B", -30, -40, -30, 40, { door(0, 4.5) }, { color = Color3.fromRGB(80, 80, 84), material = M.Concrete })
	wall(b, "B", -30, 40, 60, 40)
	wall(b, "B", -60, 40, -30, 40, nil, { color = Color3.fromRGB(150, 155, 160), material = M.Metal })
	-- escape tunnel
	wall(b, "B", -100, -34, -60, -34, nil, brick)
	wall(b, "B", -100, -26, -60, -26, nil, brick)
	wall(b, "B", -100, -34, -100, -26, nil, brick)
	P(b, Vector3.new(41, 0.8, 9), CFrame.new(-80.5, -1.6, -30), Color3.fromRGB(50, 50, 52), M.Concrete) -- tunnel ceiling

	------------------------------------------------------------------ TUNNELS
	local tunnels = Build.Folder(b, "Tunnels")
	Props.Pipe(tunnels, V(58.5, y + 11.5, -48), V(58.5, y + 11.5, 38), 1)
	Props.Pipe(tunnels, V(57, y + 12, -48), V(57, y + 12, 38), 0.6, Color3.fromRGB(70, 70, 74))
	Props.Pipe(tunnels, V(-28, y + 11.5, 37), V(58, y + 11.5, 37), 1)
	for _, z in { -30, -8, 14, 34 } do
		Props.CageLamp(tunnels, V(56, y + 13, z), "B")
	end
	for _, x in { -20, 4, 28 } do
		Props.CageLamp(tunnels, V(x, y + 13, 36), "B")
	end
	Props.Wheelchair(tunnels, At(56, y, 2, "S"))
	Props.Debris(tunnels, V(56, y, 22), 6, 401)
	Props.WallText(tunnels, At(59.5, y + 6, -10, "W"), 10, 3, "إنه يسمعك")
	Props.DragMarks(tunnels, V(56, y, -36), V(56, y, -22))
	for _, pos in { V(55, y, -12), V(20, y, 36), V(-12, y, 35) } do
		D(tunnels, Vector3.new(4, 0.05, 3), CFrame.new(pos + V(0, 0.03, 0)), Color3.fromRGB(16, 20, 24), M.Glass, { transparency = 0.2, reflect = 0.3 })
	end
	for z = -36, 36, 12 do
		wp("B", 56, z)
	end
	for x = -24, 48, 12 do
		wp("B", x, 36)
	end
	Run.SetPoint("BasementLanding", CFrame.new(56, y + 3, -36))

	------------------------------------------------------------------ BOILER ROOM
	local boiler = Build.Folder(b, "BoilerRoom")
	Props.Boiler(boiler, At(24, y, -32, "N"))
	Props.Boiler(boiler, At(38, y, -32, "N"))
	Props.Desk(boiler, At(30, y, -4.4, "S"), { width = 6, chair = false, color = Color3.fromRGB(80, 70, 60) })
	Pickups.Document(boiler, CFrame.new(30.5, y + 3.17, -4.8), "maintenance_note")
	Hiding.Add(Props.Locker(boiler, At(48, y, -38.4, "N")))
	Hiding.Add(Props.Locker(boiler, At(17, y, -4.4, "S")))
	D(boiler, Vector3.new(6, 2, 5), CFrame.new(46, y + 1, -6) * CFrame.Angles(0, 0.3, 0.1), Color3.fromRGB(20, 20, 22), M.Slate) -- coal
	for _, x in { 20, 32, 44 } do
		Props.Pipe(boiler, V(x, y + 11, -40), V(x, y + 11, -2), 0.8)
	end
	Props.CageLamp(boiler, V(31, y + 13, -20), "B")
	Pickups.Add(boiler, CFrame.new(28.5, y + 3.17, -4.2), "Battery")
	Doors.Add(b, { id = "BoilerDoor", cf = At(52, y, -20, "E"), w = 5, style = "metal", label = "غرفة الغلاية" })
	Doors.Add(b, { id = "BoilerStorageDoor", cf = At(14, y, -20, "E"), w = 5, style = "metal", label = "المخزن السفلي" })
	wp("B", 31, -20)
	wp("B", 31, -10)

	------------------------------------------------------------------ GENERATOR ROOM
	local gen = Build.Folder(b, "GeneratorRoom")
	local genModel, statusLight = Props.Generator(gen, At(32, y, 18, "S"))
	Puzzles.Generator(genModel, statusLight, V(34.8, y + 3.5, 14.2))
	for i = 0, 2 do
		Props.Barrel(gen, At(18 + i * 2.6, y, 28, "S"), Color3.fromRGB(150, 24, 20))
	end
	Build.Text(gen, Vector3.new(6, 1.2, 0.1), At(32, y + 9, 31.55, "S"), "المولّد - خطر", { bg = Color3.fromRGB(200, 170, 40), color = C.Black, font = Enum.Font.GothamBold })
	Hiding.Add(Props.Locker(gen, At(48.4, y, 28, "W")))
	Hiding.Add(Props.Locker(gen, At(16.6, y, 4, "E")))
	Props.CageLamp(gen, V(32, y + 13, 8), "B")
	Doors.Add(b, { id = "GeneratorDoor", cf = At(52, y, 15, "E"), w = 5, style = "metal", label = "غرفة المولّد" })
	Run.SetPoint("Generator", CFrame.new(44, y + 3, 8))
	wp("B", 32, 6)
	wp("B", 44, 26)

	------------------------------------------------------------------ UNDERGROUND STORAGE
	local st = Build.Folder(b, "UndergroundStorage")
	for i, z in { -30, -16, 16 } do
		Props.Shelf(st, At(-8, y, z, "S"), { width = 10, fill = "boxes", seed = 410 + i, height = 10 })
	end
	Props.Shelf(st, At(-29.1, y, -9, "E"), { width = 8, fill = "boxes", seed = 420, height = 10 })
	Props.Shelf(st, At(-29.1, y, 9, "E"), { width = 8, fill = "boxes", seed = 421, height = 10 })
	for i, pos in { V(-20, y, -34), V(-14, y, -34), V(-20, y, 26), V(4, y, 26) } do
		Props.Sheeted(st, At(pos.X, y, pos.Z, "N"), 4 + (i % 2), 3 + i % 3, 3.5)
	end
	Pickups.Add(st, CFrame.new(-16.8, y, -31), "FuelCan", { hold = 0.8 })
	Hiding.Add(Props.Wardrobe(st, At(6, y, -38.4, "N"), { color = Color3.fromRGB(70, 60, 50) }))
	for _, pos in { V(2, y, 6), V(6, y, 9), V(-22, y, 0) } do
		Props.Crate(st, At(pos.X, y, pos.Z, "N"))
	end
	Pickups.Add(st, CFrame.new(2, y + 3, 6), "Bandage")
	Props.CageLamp(st, V(-8, y + 13, -24), "B")
	Props.CageLamp(st, V(-8, y + 13, 4), "B")
	Props.CageLamp(st, V(-8, y + 13, 24), "B")
	Doors.Add(b, { id = "StorageTunnelDoor", cf = At(-8, y, 32, "N"), w = 5, style = "metal", label = "المخزن السفلي" })
	-- the hidden laboratory door (code = the night Lina vanished, DDMM)
	Doors.Add(b, {
		id = "LabDoor",
		cf = At(-30, y, 0, "E"),
		w = 4.5,
		style = "lab",
		label = "باب فولاذي",
		locked = true,
		lockedText = "باب فولاذي مخفي خلف الرفوف. لوحة الأرقام بجانبه بلا كهرباء.",
	})
	Puzzles.Keypad(b, At(-29.5, y + 4.8, 3.4, "E"), {
		id = "Laboratory",
		code = Config.Codes.Laboratory,
		title = "المختبر",
		zone = "B",
		onSolved = function()
			Doors.Unlock("LabDoor")
			Doors.SetOpen("LabDoor", true)
		end,
	})
	for _, p in { { -8, -36 }, { 0, -8 }, { -20, 6 }, { 0, 24 }, { -20, -20 } } do
		wp("B", p[1], p[2])
	end

	------------------------------------------------------------------ LABORATORY
	local lab = Build.Folder(b, "Laboratory")
	Build.Slab(lab, { -59.6, -39.6, -30.4, 39.6 }, nil, Y.B + 0.06, 0.2, Color3.fromRGB(150, 156, 158), M.CeramicTiles, { name = "Floor" })
	local heart = Build.Model(lab, "Heart")
	Build.Cyl(heart, 8, 1.6, V(-45, y + 0.8, 0), C.Charcoal, M.Metal)
	Build.Cyl(heart, 3, 4, V(-45, y + 3.6, 0), C.Rust, M.CorrodedMetal)
	local core = Build.Ball(heart, 5, V(-45, y + 8, 0), Color3.fromRGB(170, 10, 20), M.Neon, { name = "Core" })
	core.CanCollide = true
	for i = 0, 2 do
		D(heart, Vector3.new(0.4, 9, 9), CFrame.new(-45, y + 8, 0) * CFrame.Angles(i * 1.05, i * 0.6, math.rad(90)), C.DimGold, M.Metal, { shape = Enum.PartType.Cylinder, transparency = 0.7 })
	end
	for _, target in { V(-59, y + 12, 0), V(-45, y + 12.6, 39), V(-45, y + 12.6, -39), V(-31, y + 12, 10) } do
		Props.Pipe(heart, V(-45, y + 8, 0), target, 0.5, Color3.fromRGB(40, 20, 24))
	end
	local heartLight = Instance.new("PointLight")
	heartLight.Color = Color3.fromRGB(255, 30, 40)
	heartLight.Range = 32
	heartLight.Brightness = 2
	heartLight.Shadows = true
	heartLight.Parent = core
	Hotel.Refs.Heart = heart
	Hotel.Refs.HeartCore = core
	Hotel.Refs.HeartLight = heartLight
	-- console (final choice)
	local console = Build.Model(lab, "Console")
	P(console, Vector3.new(6, 3.4, 2.4), CFrame.new(-45, y + 1.7, 11), Color3.fromRGB(70, 74, 78), M.Metal)
	local screen = Build.Text(console, Vector3.new(5, 2.4, 0.1), At(-45, y + 4.8, 10.4, "S") * CFrame.Angles(math.rad(-20), 0, 0), "القلب\n\nختم  /  تدمير  /  احتفاظ", {
		bg = Color3.fromRGB(20, 6, 6),
		color = Color3.fromRGB(255, 80, 70),
		font = Enum.Font.Code,
		brightness = 2,
		lightInfluence = 0,
	})
	Hotel.Refs.Console = screen
	for _, pos in { V(-55, y, 34), V(-45, y, 34), V(-35, y, 34), V(-55, y, -34), V(-35, y, -34) } do
		Props.SpecimenTank(lab, CFrame.new(pos), { liquid = pos.Z > 0 and Color3.fromRGB(60, 160, 120) or Color3.fromRGB(80, 120, 200) })
	end
	Props.OperatingTable(lab, At(-37, y, -18, "N"))
	Props.LabBench(lab, At(-58.4, y, 16, "E"), 10)
	Props.LabBench(lab, At(-58.4, y, -12, "E"), 10)
	Pickups.Document(lab, CFrame.new(-58, y + 3.45, 16), "lab_report")
	Props.Chalkboard(lab, At(-45, y + 7, 39.5, "S"), 16, 5, "الموضوع 47 - القلب\nسنوات(الضيوف) ← الخلود\nل. فارن = المفتاح ؟")
	for i = 0, 3 do
		D(lab, Vector3.new(0.2, 8, 0.2), CFrame.new(-34 + i * 0.8, y + 4, -38), C.Charcoal, M.Metal)
	end
	Props.BloodStain(lab, V(-38, y, -24), 2.4, 451)
	Props.CageLamp(lab, V(-45, y + 13, 24), "B", { color = Color3.fromRGB(220, 230, 255) })
	Props.CageLamp(lab, V(-45, y + 13, -24), "B", { color = Color3.fromRGB(220, 230, 255) })
	Build.Text(lab, Vector3.new(6, 1, 0.1), At(-59.5, y + 11, -30, "E"), "نفق الخدمة", { bg = Color3.fromRGB(20, 60, 30), color = Color3.fromRGB(150, 255, 170), font = Enum.Font.GothamBold, lightInfluence = 0 })
	Doors.Add(b, { id = "ExitGate", cf = At(-60, y, -30, "E"), w = 6, h = 10, style = "steel", double = true, label = "نفق الخدمة", locked = true, lockedText = "الباب المصفّح مختوم. لوحة التحكم هي التي تفتحه.", noPrompt = false })
	Run.SetPoint("Lab", CFrame.new(-36, y + 3, 20))
	for _, p in { { -36, 20 }, { -36, -20 }, { -52, 0 }, { -52, 26 }, { -52, -26 } } do
		wp("B", p[1], p[2])
	end

	------------------------------------------------------------------ ESCAPE TUNNEL
	local esc = Build.Folder(b, "EscapeTunnel")
	for x = -95, -65, 10 do
		Props.CageLamp(esc, V(x, -2.2, -30), "Escape", { color = Config.Palette.Emergency, brightness = 1.2 })
	end
	Props.Pipe(esc, V(-100, -3, -33), V(-60, -3, -33), 0.6)
	Props.Debris(esc, V(-80, y, -30), 6, 501)
	local daylight = D(esc, Vector3.new(0.2, 8, 6), CFrame.new(-99.7, y + 5, -30), Color3.fromRGB(230, 240, 255), M.Neon, { name = "Daylight" })
	local day = Instance.new("SurfaceLight")
	day.Face = Enum.NormalId.Right
	day.Range = 40
	day.Brightness = 3
	day.Color = Color3.fromRGB(220, 235, 255)
	day.Parent = daylight
	local ladder = Instance.new("TrussPart")
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 12, 2)
	ladder.CFrame = CFrame.new(-98, y + 6, -27.5)
	ladder.Color = C.Rust
	ladder.Material = M.CorrodedMetal
	ladder.Parent = esc
	Build.Text(esc, Vector3.new(4, 1.2, 0.1), At(-90, y + 10, -33.5, "N"), "مخرج", { bg = Color3.fromRGB(20, 60, 30), color = Color3.fromRGB(150, 255, 170), font = Enum.Font.GothamBold, lightInfluence = 0 })
	Hotel.Refs.ExitZone = { min = V(-100, y - 2, -34), max = V(-90, y + 12, -26) }
	Hotel.Refs.EscapeShadowSpawn = V(-36, y, 30)
	wp("B", -80, -30)
end

----------------------------------------------------------------------------------------
-- Build entry point
----------------------------------------------------------------------------------------

function Hotel.Build(): Model
	local existing = Workspace:FindFirstChild("Hotel")
	if existing then
		existing:Destroy()
	end
	Hotel.Refs = {}
	Run.ResetMapData()
	local map = Instance.new("Model")
	map.Name = "Hotel"
	Run.Map = map
	Build.Folder(map, "Monsters")
	slabs(map)
	exterior(map)
	groundFloor(map)
	firstFloor(map)
	secondFloor(map)
	thirdFloor(map)
	basement(map)
	Elevator.Build(map)
	-- zones used by the session triggers
	Hotel.Refs.LobbyZone = { min = V(-20, -1, -43), max = V(20, 12, 12) }
	Hotel.Refs.LabZone = { min = V(-60, Y.B - 1, -40), max = V(-31, Y.B + 12, 40) }
	Hotel.Refs.F3Zone = { min = V(-60, Y.F3 - 1, -50), max = V(60, Y.F3 + 14, 50) }
	Hotel.Refs.BasementZone = { min = V(-60, Y.B - 1, -50), max = V(60, Y.B + 12, 50) }
	Hotel.Refs.Room308Zone = { min = V(40, Y.F3 - 1, -6), max = V(60, Y.F3 + 12, 6) }
	map.Parent = Workspace
	return map
end

return Hotel
