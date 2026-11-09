--!nonstrict
-- Low-level geometry helpers used by the procedural hotel builder.
-- All geometry is axis aligned and anchored. Decorative parts are made non-collidable
-- and non-touchable so physics, pathfinding and raycasts stay cheap.

local CollectionService = game:GetService("CollectionService")

local Build = {}

local Smooth = Enum.SurfaceType.Smooth

-- Generic part constructor.
-- opts: shape, transparency, collide(false), reflect, shadow(false), name, class, decor(true)
function Build.P(parent: Instance, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, opts: { [string]: any }?): BasePart
	local part: BasePart
	if opts and opts.class then
		part = Instance.new(opts.class)
	else
		part = Instance.new("Part")
	end
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color or Color3.new(0.5, 0.5, 0.5)
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Smooth
	part.BottomSurface = Smooth
	if opts then
		if opts.shape then
			(part :: Part).Shape = opts.shape
		end
		if opts.transparency then
			part.Transparency = opts.transparency
		end
		if opts.collide == false or opts.decor then
			part.CanCollide = false
		end
		if opts.decor then
			part.CanTouch = false
			part.CanQuery = false
		end
		if opts.reflect then
			part.Reflectance = opts.reflect
		end
		if opts.shadow == false then
			part.CastShadow = false
		end
		if opts.name then
			part.Name = opts.name
		end
	end
	part.Parent = parent
	return part
end

-- Decorative (non-colliding) part shorthand.
function Build.D(parent, size, cf, color, material, opts)
	opts = opts or {}
	opts.decor = true
	return Build.P(parent, size, cf, color, material, opts)
end

-- Vertical cylinder centred at `pos` (height along Y).
function Build.Cyl(parent, diameter: number, height: number, pos: Vector3 | CFrame, color, material, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	local base = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	return Build.P(parent, Vector3.new(height, diameter, diameter), base * CFrame.Angles(0, 0, math.rad(90)), color, material, opts)
end

function Build.Ball(parent, diameter: number, pos: Vector3, color, material, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Ball
	return Build.P(parent, Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, material, opts)
end

function Build.Model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.Folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local DIRS = {
	N = Vector3.new(0, 0, 1),
	S = Vector3.new(0, 0, -1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}
Build.Dirs = DIRS

-- CFrame at (x,y,z) whose LookVector (the prop's "front") points toward compass direction.
function Build.At(x: number, y: number, z: number, facing: string?): CFrame
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + DIRS[facing or "S"])
end

-- Axis-aligned wall from (x1,z1) to (x2,z2) starting at height y.
-- openings: { {c = centre along the wall axis, w = width, h = height, b = bottom (default 0), fill = fn?} }
-- style: { color, material, thickness, trim (Color3 for baseboards), name }
function Build.Wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, y: number, h: number, style, openings)
	openings = openings or {}
	local alongX = math.abs(z1 - z2) < 0.01
	local s0 = alongX and math.min(x1, x2) or math.min(z1, z2)
	local s1 = alongX and math.max(x1, x2) or math.max(z1, z2)
	local fixed = alongX and z1 or x1
	local t = style.thickness or 0.8
	local parts = {}

	local function seg(a: number, b: number, bottom: number, top: number)
		if b - a < 0.05 or top - bottom < 0.05 then
			return
		end
		local len = b - a
		local mid = (a + b) / 2
		local cy = y + (bottom + top) / 2
		local size = alongX and Vector3.new(len, top - bottom, t) or Vector3.new(t, top - bottom, len)
		local pos = alongX and Vector3.new(mid, cy, fixed) or Vector3.new(fixed, cy, mid)
		local part = Build.P(parent, size, CFrame.new(pos), style.color, style.material, { name = style.name or "Wall" })
		table.insert(parts, part)
	end

	local function trim(a: number, b: number)
		if not style.trim or b - a < 0.3 then
			return
		end
		local len = b - a
		local mid = (a + b) / 2
		for _, side in { -1, 1 } do
			local off = side * (t / 2 + 0.1)
			local size = alongX and Vector3.new(len, 0.9, 0.2) or Vector3.new(0.2, 0.9, len)
			local pos = alongX and Vector3.new(mid, y + 0.45, fixed + off) or Vector3.new(fixed + off, y + 0.45, mid)
			Build.D(parent, size, CFrame.new(pos), style.trim, Enum.Material.Wood)
		end
	end

	table.sort(openings, function(a, b)
		return a.c < b.c
	end)
	local cursor = s0
	local trimCursor = s0
	for _, o in openings do
		local oa, ob = o.c - o.w / 2, o.c + o.w / 2
		local bottom = o.b or 0
		seg(cursor, oa, 0, h)
		seg(oa, ob, 0, bottom)
		seg(oa, ob, bottom + o.h, h)
		if bottom <= 0.01 then
			trim(trimCursor, oa)
			trimCursor = ob
		end
		cursor = ob
	end
	seg(cursor, s1, 0, h)
	trim(trimCursor, s1)
	return parts
end

-- Splits rectangle (x1,z1,x2,z2) minus rectangular holes into parts at height range.
function Build.Slab(parent: Instance, rect, holes, yTop: number, thickness: number, color: Color3, material: Enum.Material, opts)
	holes = holes or {}
	local xs, zs = { rect[1], rect[3] }, { rect[2], rect[4] }
	for _, hole in holes do
		for _, v in { hole[1], hole[3] } do
			if v > rect[1] and v < rect[3] then
				table.insert(xs, v)
			end
		end
		for _, v in { hole[2], hole[4] } do
			if v > rect[2] and v < rect[4] then
				table.insert(zs, v)
			end
		end
	end
	table.sort(xs)
	table.sort(zs)
	local function solid(cx, cz)
		for _, hole in holes do
			if cx > hole[1] and cx < hole[3] and cz > hole[2] and cz < hole[4] then
				return false
			end
		end
		return true
	end
	local parts = {}
	for j = 1, #zs - 1 do
		local za, zb = zs[j], zs[j + 1]
		if zb - za > 0.01 then
			local runStart = nil
			for i = 1, #xs do
				local isSolid = false
				if i < #xs and xs[i + 1] - xs[i] > 0.01 then
					isSolid = solid((xs[i] + xs[i + 1]) / 2, (za + zb) / 2)
				end
				if isSolid and not runStart then
					runStart = xs[i]
				elseif not isSolid and runStart then
					local xa, xb = runStart, xs[i]
					local part = Build.P(
						parent,
						Vector3.new(xb - xa, thickness, zb - za),
						CFrame.new((xa + xb) / 2, yTop - thickness / 2, (za + zb) / 2),
						color,
						material,
						opts
					)
					table.insert(parts, part)
					runStart = nil
				end
			end
		end
	end
	return parts
end

-- Floor finish (carpet, marble...) for a room rectangle.
function Build.Floor(parent, x1, z1, x2, z2, y, color, material)
	return Build.P(parent, Vector3.new(x2 - x1, 0.2, z2 - z1), CFrame.new((x1 + x2) / 2, y - 0.1, (z1 + z2) / 2), color, material, { name = "Floor" })
end

-- Text on the front face of a thin part. Used for signs, plaques, wall writing.
function Build.Text(parent, size: Vector3, cf: CFrame, text: string, opts)
	opts = opts or {}
	local part = Build.D(parent, size, cf, opts.bg or Color3.new(0, 0, 0), opts.material or Enum.Material.SmoothPlastic, {
		transparency = opts.bgTransparency or 0,
		name = opts.name or "Sign",
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.ppu or 40
	gui.LightInfluence = opts.lightInfluence or 1
	gui.Brightness = opts.brightness or 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = opts.font or Enum.Font.Bodoni
	label.TextColor3 = opts.color or Color3.fromRGB(178, 142, 74)
	label.TextTransparency = opts.textTransparency or 0
	label.Rotation = opts.rotation or 0
	label.Parent = gui
	return part, label
end

-- Light helpers. Every powered hotel light is tagged so the Power service can control it.
function Build.Light(parent: Instance, kind: string, props, zone: string?, powered: boolean?)
	local light = Instance.new(kind)
	for key, value in props do
		light[key] = value
	end
	light.Parent = parent
	if zone and powered ~= false then
		light:SetAttribute("Zone", zone)
		light:SetAttribute("BaseBrightness", light.Brightness)
		CollectionService:AddTag(light, "HotelLight")
	end
	return light
end

-- Deterministic random generator so the hotel looks identical every build.
function Build.Rng(seed: number)
	return Random.new(seed)
end

function Build.Tag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
	return instance
end

return Build
