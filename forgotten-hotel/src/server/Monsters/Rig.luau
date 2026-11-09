--!nonstrict
-- Builds the three monster rigs from parts and Motor6D joints (no external assets).
-- Joint names (RootJoint, Neck, LShoulder, RShoulder, LHip, RHip) are animated
-- procedurally on every client by client/MonsterAnimator via Motor6D.Transform.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Rig = {}
local C = Config.Palette
local M = Enum.Material

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?, cf: CFrame?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = cf or CFrame.new()
	p.CollisionGroup = "Monsters"
	p.Parent = model
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

-- Welds a decoration to a body part at an offset relative to that part.
local function deco(model: Model, base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = part(model, name, size, color, material, base.CFrame * offset)
	if shape then
		p.Shape = shape
	end
	p.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- spec: hip (root bottom height), torso {size, y}, head {size, y}, arm {size, shoulderX, shoulderY},
-- leg {size, hipX, hipY}, colors
local function build(name: string, spec)
	local model = Instance.new("Model")
	model.Name = name
	local rootY = spec.hip + 1
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(), M.SmoothPlastic, CFrame.new(0, rootY, 0))
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	model.PrimaryPart = root

	local torso = part(model, "Torso", spec.torso.size, spec.body, spec.material, CFrame.new(0, spec.torso.y, 0))
	motor("RootJoint", root, torso, CFrame.new(0, spec.torso.y - rootY, 0), CFrame.new())

	local head = part(model, "Head", spec.head.size, spec.headColor or spec.body, spec.headMaterial or spec.material, CFrame.new(0, spec.head.y, 0))
	local neckY = spec.torso.y + spec.torso.size.Y / 2
	motor("Neck", torso, head, CFrame.new(0, neckY - spec.torso.y, 0), CFrame.new(0, neckY - spec.head.y, 0))

	for _, side in { "L", "R" } do
		local sx = side == "L" and -1 or 1
		local armLen = spec.arm.size.Y
		local shoulder = Vector3.new(sx * spec.arm.x, spec.arm.y, 0)
		local arm = part(model, side .. "Arm", spec.arm.size, spec.armColor or spec.body, spec.material, CFrame.new(shoulder - Vector3.new(0, armLen / 2, 0)))
		motor(side .. "Shoulder", torso, arm, CFrame.new(shoulder - Vector3.new(0, spec.torso.y, 0)), CFrame.new(0, armLen / 2, 0))
		local legLen = spec.leg.size.Y
		local hip = Vector3.new(sx * spec.leg.x, spec.leg.y, 0)
		local leg = part(model, side .. "Leg", spec.leg.size, spec.legColor or spec.body, spec.material, CFrame.new(hip - Vector3.new(0, legLen / 2, 0)))
		motor(side .. "Hip", torso, leg, CFrame.new(hip - Vector3.new(0, spec.torso.y, 0)), CFrame.new(0, legLen / 2, 0))
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = spec.hip
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutomaticScalingEnabled = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 8
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	model:SetAttribute("Style", spec.style)
	model:SetAttribute("Anim", "idle")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "MonsterRig")
	return model, root, torso, head, humanoid
end

function Rig.Shadow()
	local black = Color3.fromRGB(8, 8, 10)
	local model, root, torso, head, humanoid = build("TheShadow", {
		style = "shadow",
		hip = 3.6,
		body = black,
		material = M.SmoothPlastic,
		torso = { size = Vector3.new(2.2, 3.4, 1.1), y = 5.6 },
		head = { size = Vector3.new(1.4, 1.9, 1.4), y = 8.3 },
		arm = { size = Vector3.new(0.55, 4.8, 0.55), x = 1.4, y = 7.0 },
		leg = { size = Vector3.new(0.7, 3.9, 0.7), x = 0.6, y = 3.9 },
	})
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			p.Transparency = 0.04
			p.Reflectance = 0
		end
	end
	-- elongated fingers
	for _, side in { "LArm", "RArm" } do
		local arm = model:FindFirstChild(side)
		for i = -1, 1 do
			deco(model, arm, "Finger", Vector3.new(0.12, 1.4, 0.12), CFrame.new(i * 0.16, -3, 0) * CFrame.Angles(0, 0, math.rad(i * 8)), black)
		end
	end
	for _, x in { -0.32, 0.32 } do
		local eye = deco(model, head, "Eye", Vector3.new(0.28, 0.14, 0.1), CFrame.new(x, 0.2, -0.72), Color3.fromRGB(255, 40, 30), M.Neon)
		eye.Name = "Eye"
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 40, 30)
	glow.Range = 9
	glow.Brightness = 1.2
	glow.Parent = head
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(5, 5, 6))
	smoke.Rate = 14
	smoke.Lifetime = NumberRange.new(1, 2)
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.LightInfluence = 0
	smoke.Parent = torso
	local breathing = Sounds.Make("Breathing", head)
	if breathing then
		breathing.Name = "Breathing"
	end
	return model, root, head, humanoid
end

function Rig.Concierge()
	local jacket = C.Burgundy
	local model, root, torso, head, humanoid = build("TheConcierge", {
		style = "concierge",
		hip = 2.1,
		body = jacket,
		material = M.Fabric,
		headColor = Color3.fromRGB(214, 206, 196),
		headMaterial = M.SmoothPlastic,
		legColor = C.Black,
		torso = { size = Vector3.new(2, 2.6, 1), y = 4.4 },
		head = { size = Vector3.new(1.2, 1.4, 1.2), y = 6.45 },
		arm = { size = Vector3.new(0.55, 2.6, 0.55), x = 1.28, y = 5.5 },
		leg = { size = Vector3.new(0.8, 3.1, 0.8), x = 0.5, y = 3.1 },
	})
	for i = 0, 2 do
		deco(model, torso, "Button", Vector3.new(0.2, 0.2, 0.1), CFrame.new(0, 0.7 - i * 0.6, -0.52), C.Gold, M.Metal)
	end
	deco(model, torso, "Collar", Vector3.new(1, 0.5, 0.1), CFrame.new(0, 1.05, -0.52), C.Bone, M.Fabric)
	deco(model, torso, "Bowtie", Vector3.new(0.6, 0.25, 0.12), CFrame.new(0, 1.1, -0.58), C.Black, M.Fabric)
	deco(model, head, "Hat", Vector3.new(0.6, 1.3, 1.3), CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), jacket, M.Fabric, Enum.PartType.Cylinder)
	deco(model, head, "HatBand", Vector3.new(0.15, 1.32, 1.32), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Gold, M.Metal, Enum.PartType.Cylinder)
	for _, x in { -0.25, 0.25 } do
		deco(model, head, "EyeHole", Vector3.new(0.25, 0.18, 0.05), CFrame.new(x, 0.15, -0.6), Color3.fromRGB(4, 4, 4))
	end
	deco(model, head, "Smile", Vector3.new(0.6, 0.06, 0.05), CFrame.new(0, -0.35, -0.6), Color3.fromRGB(60, 10, 10))
	for _, side in { "LArm", "RArm" } do
		local arm = model:FindFirstChild(side)
		deco(model, arm, "Glove", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, -1.3, 0), Color3.fromRGB(235, 232, 225), M.Fabric)
	end
	return model, root, head, humanoid
end

function Rig.Roomkeeper()
	local dress = Color3.fromRGB(205, 198, 182)
	local model, root, torso, head, humanoid = build("TheRoomkeeper", {
		style = "roomkeeper",
		hip = 2.4,
		body = dress,
		material = M.Fabric,
		headColor = Color3.fromRGB(232, 226, 214),
		headMaterial = M.SmoothPlastic,
		armColor = Color3.fromRGB(190, 182, 170),
		legColor = Color3.fromRGB(150, 140, 130),
		torso = { size = Vector3.new(1.8, 2.8, 1), y = 4.6 },
		head = { size = Vector3.new(1.2, 1.5, 1.2), y = 6.75 },
		arm = { size = Vector3.new(0.4, 4.6, 0.4), x = 1.1, y = 5.7 },
		leg = { size = Vector3.new(0.5, 3.4, 0.5), x = 0.4, y = 3.4 },
	})
	deco(model, torso, "Skirt", Vector3.new(3.4, 3, 3), CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), dress, M.Fabric, Enum.PartType.Cylinder)
	deco(model, head, "Hair", Vector3.new(1.35, 2.6, 1.0), CFrame.new(0, -0.5, 0.25), Color3.fromRGB(10, 8, 8), M.Fabric)
	deco(model, head, "HairTop", Vector3.new(1.35, 0.4, 1.35), CFrame.new(0, 0.75, 0), Color3.fromRGB(10, 8, 8), M.Fabric)
	for _, x in { -0.25, 0.25 } do
		deco(model, head, "EyeHole", Vector3.new(0.28, 0.32, 0.05), CFrame.new(x, 0.1, -0.61), Color3.fromRGB(2, 2, 2))
	end
	deco(model, head, "Crack", Vector3.new(0.05, 0.8, 0.05), CFrame.new(0.15, 0.2, -0.62) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(30, 20, 20))
	deco(model, head, "Mouth", Vector3.new(0.35, 0.5, 0.05), CFrame.new(0, -0.45, -0.61), Color3.fromRGB(20, 4, 4))
	for _, side in { "LArm", "RArm" } do
		local arm = model:FindFirstChild(side)
		for i = -1, 1 do
			deco(model, arm, "Finger", Vector3.new(0.08, 1, 0.08), CFrame.new(i * 0.12, -2.7, 0), Color3.fromRGB(190, 182, 170))
		end
	end
	return model, root, head, humanoid
end

return Rig
