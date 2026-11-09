--!nonstrict
-- Procedural animation for the monster rigs (no animation assets needed). Every client
-- animates nearby monsters locally through Motor6D.Transform, driven by the "Anim" and
-- "Style" attributes the server sets, plus the rig's actual velocity.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MonsterAnimator = {}
local rigs = {}

local function setup(model: Model)
	if rigs[model] then
		return
	end
	local torso = model:WaitForChild("Torso", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not torso or not root then
		return
	end
	local joints = {}
	for _, name in { "Neck", "LShoulder", "RShoulder", "LHip", "RHip" } do
		joints[name] = torso:WaitForChild(name, 5)
	end
	joints.RootJoint = root:WaitForChild("RootJoint", 5)
	rigs[model] = { joints = joints, root = root, t = math.random() * 10, seed = math.random() * 100, twitch = 0, twitchTarget = 0 }
end

local function set(joint: Motor6D?, cf: CFrame)
	if joint then
		joint.Transform = cf
	end
end

local A = CFrame.Angles

local function animateShadow(rig, anim: string, speed: number, t: number)
	local j = rig.joints
	if anim == "attack" then
		local s = math.sin(t * 18) * 0.15
		set(j.LShoulder, A(math.rad(150) + s, 0, math.rad(-15)))
		set(j.RShoulder, A(math.rad(150) - s, 0, math.rad(15)))
		set(j.RootJoint, A(math.rad(-25), 0, 0))
		set(j.Neck, A(math.rad(-20), 0, 0))
		set(j.LHip, A(math.rad(20), 0, 0))
		set(j.RHip, A(math.rad(-20), 0, 0))
		return
	end
	local run = anim == "run"
	local freq = run and 9 or (anim == "walk" and 5 or 0)
	local swing = run and 0.9 or (anim == "walk" and 0.5 or 0)
	local phase = math.sin(t * freq)
	set(j.LHip, A(phase * swing, 0, 0))
	set(j.RHip, A(-phase * swing, 0, 0))
	if run then
		-- arms reach forward, twitching
		local jitter = math.sin(t * 31 + rig.seed) * 0.12
		set(j.LShoulder, A(math.rad(70) + jitter - phase * 0.3, 0, math.rad(-8)))
		set(j.RShoulder, A(math.rad(70) - jitter + phase * 0.3, 0, math.rad(8)))
		set(j.RootJoint, A(math.rad(-22), math.sin(t * freq) * 0.08, 0))
		set(j.Neck, A(math.rad(10), 0, math.sin(t * 13) * 0.15))
	elseif anim == "walk" then
		set(j.LShoulder, A(-phase * 0.35, 0, math.rad(-4)))
		set(j.RShoulder, A(phase * 0.35, 0, math.rad(4)))
		set(j.RootJoint, A(math.rad(-10), 0, math.sin(t * 2.5) * 0.04))
		set(j.Neck, A(0, math.sin(t * 0.7) * 0.4, math.rad(12)))
	else
		local breathe = math.sin(t * 1.4) * 0.05
		set(j.LShoulder, A(breathe, 0, math.rad(-6)))
		set(j.RShoulder, A(breathe, 0, math.rad(6)))
		set(j.RootJoint, A(math.rad(-6) + breathe, 0, 0))
		-- sudden head twitches
		if t > rig.twitch then
			rig.twitch = t + 0.8 + math.random() * 2
			rig.twitchTarget = (math.random() - 0.5) * 1.6
		end
		set(j.Neck, A(0, 0, rig.twitchTarget))
		set(j.LHip, CFrame.new())
		set(j.RHip, CFrame.new())
	end
end

local function animateConcierge(rig, _anim: string, _speed: number, t: number)
	local j = rig.joints
	local breathe = math.sin(t * 1.1) * 0.03
	-- slow, unnatural head tilt; hands folded in front
	set(j.Neck, A(math.rad(-8), 0, math.rad(18) + math.sin(t * 0.35) * math.rad(14)))
	set(j.LShoulder, A(math.rad(30) + breathe, 0, math.rad(25)))
	set(j.RShoulder, A(math.rad(30) + breathe, 0, math.rad(-25)))
	set(j.RootJoint, A(breathe * 0.5 + (math.sin(t * 0.25) > 0.97 and math.rad(25) or 0), 0, 0))
	set(j.LHip, CFrame.new())
	set(j.RHip, CFrame.new())
end

local function animateRoomkeeper(rig, anim: string, _speed: number, t: number)
	local j = rig.joints
	if anim == "attack" then
		set(j.LShoulder, A(math.rad(160), 0, math.rad(-20)))
		set(j.RShoulder, A(math.rad(160), 0, math.rad(20)))
		set(j.RootJoint, A(math.rad(-35), 0, 0))
		set(j.Neck, A(math.rad(-30), 0, math.rad(40)))
		return
	end
	-- hunched, head bent at a wrong angle, arms dangling; "skip" adds violent jerks
	local jerk = anim == "skip" and (math.random() - 0.5) * 0.6 or 0
	set(j.RootJoint, A(math.rad(-28) + jerk * 0.3, jerk, 0))
	set(j.Neck, A(math.rad(15), 0, math.rad(55) + math.sin(t * 0.8) * 0.1 + jerk))
	local sway = math.sin(t * 1.3) * 0.12
	set(j.LShoulder, A(math.rad(25) + sway + jerk, 0, math.rad(-5)))
	set(j.RShoulder, A(math.rad(25) - sway - jerk, 0, math.rad(5)))
	set(j.LHip, A(math.rad(15), 0, 0))
	set(j.RHip, A(math.rad(-5), 0, 0))
end

local STYLES = {
	shadow = animateShadow,
	concierge = animateConcierge,
	roomkeeper = animateRoomkeeper,
}

function MonsterAnimator.Init()
	for _, model in CollectionService:GetTagged("MonsterRig") do
		task.spawn(setup, model)
	end
	CollectionService:GetInstanceAddedSignal("MonsterRig"):Connect(function(model)
		task.spawn(setup, model)
	end)
	CollectionService:GetInstanceRemovedSignal("MonsterRig"):Connect(function(model)
		rigs[model] = nil
	end)
	RunService.Stepped:Connect(function(_, dt)
		local camPos = workspace.CurrentCamera.CFrame.Position
		for model, rig in rigs do
			if not model.Parent then
				continue
			end
			local root = rig.root
			if (root.Position - camPos).Magnitude < 160 then
				rig.t += dt
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				local animate = STYLES[model:GetAttribute("Style")]
				if animate then
					animate(rig, model:GetAttribute("Anim") or "idle", speed, rig.t)
				end
			end
		end
	end)
end

return MonsterAnimator
