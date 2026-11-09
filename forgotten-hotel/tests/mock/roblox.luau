--!nonstrict
-- Minimal headless mock of the Roblox engine API used by The Forgotten Hotel, so the
-- server code can be executed and integration-tested with the stand-alone `luau` CLI.
-- It favours "never crash, behave plausibly" over physical accuracy.

local M = {}
M.now = 0
M.log = {}

local function record(...)
	table.insert(M.log, table.concat({ ... }, " "))
end
M.record = record

--------------------------------------------------------------------------------
-- typeof
--------------------------------------------------------------------------------
local rawtypeof = typeof
function typeof(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt and mt.__type then
			return mt.__type
		end
	end
	return rawtypeof(v)
end

--------------------------------------------------------------------------------
-- Vector3 / Vector2
--------------------------------------------------------------------------------
local V3 = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return v3(0, 0, 0)
		end
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z)
end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

local V2 = { __type = "Vector2" }
V2.__index = V2
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2)
	end,
}
Vector2.zero = Vector2.new(0, 0)

--------------------------------------------------------------------------------
-- CFrame (position + 3x3 rotation, row major)
--------------------------------------------------------------------------------
local CF = { __type = "CFrame" }
local function cf(px, py, pz, r)
	return setmetatable({ p = v3(px, py, pz), r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
local function matmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function rotvec(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CF.__index = function(self, k)
	if k == "Position" then
		return self.p
	elseif k == "X" then
		return self.p.X
	elseif k == "Y" then
		return self.p.Y
	elseif k == "Z" then
		return self.p.Z
	elseif k == "LookVector" then
		return v3(-self.r[3], -self.r[6], -self.r[9])
	elseif k == "RightVector" then
		return v3(self.r[1], self.r[4], self.r[7])
	elseif k == "UpVector" then
		return v3(self.r[2], self.r[5], self.r[8])
	elseif k == "Inverse" then
		return function(a)
			local rt = transpose(a.r)
			local np = rotvec(rt, a.p)
			return cf(-np.X, -np.Y, -np.Z, rt)
		end
	elseif k == "ToObjectSpace" then
		return function(a, b)
			return a:Inverse() * b
		end
	elseif k == "ToWorldSpace" then
		return function(a, b)
			return a * b
		end
	elseif k == "PointToWorldSpace" then
		return function(a, v)
			return a * v
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			local p = a.p + (b.p - a.p) * t
			return cf(p.X, p.Y, p.Z, t < 0.5 and a.r or b.r)
		end
	elseif k == "GetComponents" then
		return function(a)
			return a.p.X, a.p.Y, a.p.Z, table.unpack(a.r)
		end
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	if typeof(b) == "Vector3" then
		return a.p + rotvec(a.r, b)
	end
	local p = a.p + rotvec(a.r, b.p)
	return cf(p.X, p.Y, p.Z, matmul(a.r, b.r))
end
CF.__add = function(a, v)
	return cf(a.p.X + v.X, a.p.Y + v.Y, a.p.Z + v.Z, a.r)
end
CF.__sub = function(a, v)
	return cf(a.p.X - v.X, a.p.Y - v.Y, a.p.Z - v.Z, a.r)
end
CF.__eq = function(a, b)
	return a.p == b.p
end
local function angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return matmul(matmul(X, Y), Z)
end
CFrame = {
	new = function(x, y, z, ...)
		if typeof(x) == "Vector3" then
			return cf(x.X, x.Y, x.Z)
		end
		return cf(x or 0, y or 0, z or 0)
	end,
	Angles = function(rx, ry, rz)
		return cf(0, 0, 0, angles(rx or 0, ry or 0, rz or 0))
	end,
	lookAt = function(pos, target, up)
		local look = (target - pos).Unit
		if look.Magnitude == 0 then
			return cf(pos.X, pos.Y, pos.Z)
		end
		local upv = up or v3(0, 1, 0)
		local right = look:Cross(upv).Unit
		if right.Magnitude == 0 then
			right = v3(1, 0, 0)
		end
		local up2 = right:Cross(look)
		-- columns: right, up, -look
		return cf(pos.X, pos.Y, pos.Z, { right.X, up2.X, -look.X, right.Y, up2.Y, -look.Y, right.Z, up2.Z, -look.Z })
	end,
}
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.identity = CFrame.new()

--------------------------------------------------------------------------------
-- Value types
--------------------------------------------------------------------------------
local C3 = { __type = "Color3" }
C3.__index = function(self, k)
	if k == "Lerp" then
		return function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	end
	return nil
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
	end,
	fromRGB = function(r, g, b)
		return setmetatable({ R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }, C3)
	end,
}

local function simpleType(name, fields)
	local mt = { __type = name }
	mt.__index = mt
	local t = {}
	t.new = function(...)
		local args = { ... }
		local o = {}
		for i, f in fields do
			o[f] = args[i]
		end
		return setmetatable(o, mt)
	end
	return t, mt
end

UDim = simpleType("UDim", { "Scale", "Offset" })
local udim2mt
UDim2, udim2mt = simpleType("UDim2", { "XS", "XO", "YS", "YO" })
udim2mt.__index = function(self, k)
	if k == "X" then
		return UDim.new(self.XS or 0, self.XO or 0)
	elseif k == "Y" then
		return UDim.new(self.YS or 0, self.YO or 0)
	end
	return nil
end
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end
TweenInfo = simpleType("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses" })
NumberRange = simpleType("NumberRange", { "Min", "Max" })
NumberSequenceKeypoint = simpleType("NumberSequenceKeypoint", { "Time", "Value" })
NumberSequence = simpleType("NumberSequence", { "Keypoints" })
ColorSequence = simpleType("ColorSequence", { "A", "B" })
PhysicalProperties = simpleType("PhysicalProperties", { "Density" })

local RP = { __type = "RaycastParams" }
RP.__index = RP
RaycastParams = {
	new = function()
		return setmetatable({ FilterDescendantsInstances = {} }, RP)
	end,
}

local RNG = { __type = "Random" }
RNG.__index = RNG
function RNG:NextNumber(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	local f = self.s / 2147483648
	if a then
		return a + (b - a) * f
	end
	return f
end
function RNG:NextInteger(a, b)
	return math.floor(self:NextNumber(a, b + 0.9999))
end
Random = {
	new = function(seed)
		return setmetatable({ s = math.floor(math.abs(seed or 1) * 7919) % 2147483647 + 1 }, RNG)
	end,
}

--------------------------------------------------------------------------------
-- Enum
--------------------------------------------------------------------------------
local enumCache = {}
local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = EnumItemMT
EnumItemMT.__tostring = function(self)
	return "Enum." .. self.EnumType .. "." .. self.Name
end
local valueCounter = 0
Enum = setmetatable({}, {
	__index = function(_, typeName)
		local t = enumCache[typeName]
		if not t then
			t = setmetatable({}, {
				__index = function(tt, itemName)
					valueCounter += 1
					local item = setmetatable({ Name = itemName, EnumType = typeName, Value = valueCounter }, EnumItemMT)
					rawset(tt, itemName, item)
					return item
				end,
			})
			enumCache[typeName] = t
		end
		return t
	end,
})

--------------------------------------------------------------------------------
-- Scheduler (task library, simulated clock)
--------------------------------------------------------------------------------
local queue = {}
local function schedule(at, fn, ...)
	table.insert(queue, { at = at, fn = fn, args = table.pack(...) })
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		M.errors = M.errors or {}
		table.insert(M.errors, debug.traceback(co, tostring(err)))
	end
end

local function runFn(fn, ...)
	if type(fn) == "thread" then
		resume(fn, ...)
	else
		local co = coroutine.create(fn)
		resume(co, ...)
	end
end

task = {
	spawn = function(fn, ...)
		runFn(fn, ...)
	end,
	defer = function(fn, ...)
		schedule(M.now, fn, ...)
	end,
	delay = function(t, fn, ...)
		schedule(M.now + (t or 0), fn, ...)
	end,
	wait = function(t)
		local co = coroutine.running()
		local start = M.now
		schedule(M.now + math.max(t or 0.03, 0.03), co)
		coroutine.yield()
		return M.now - start
	end,
	cancel = function() end,
}
function wait(t)
	return task.wait(t)
end

function M.advance(seconds)
	local target = M.now + seconds
	while true do
		table.sort(queue, function(a, b)
			return a.at < b.at
		end)
		local item = queue[1]
		if not item or item.at > target then
			break
		end
		table.remove(queue, 1)
		M.now = math.max(M.now, item.at)
		runFn(item.fn, table.unpack(item.args, 1, item.args.n))
	end
	M.now = target
end

local realOs = os
os = {
	clock = function()
		return M.now
	end,
	time = realOs.time,
	date = realOs.date,
	difftime = realOs.difftime,
}

warn = function(...)
	local parts = {}
	for _, v in { ... } do
		table.insert(parts, tostring(v))
	end
	record("WARN", table.concat(parts, " "))
end

--------------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------------
local SignalMT = { __type = "RBXScriptSignal" }
SignalMT.__index = SignalMT
local function newSignal()
	return setmetatable({ handlers = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	return {
		Connected = true,
		Disconnect = function()
			h.connected = false
		end,
	}
end
SignalMT.Once = SignalMT.Connect
function SignalMT:Fire(...)
	for _, h in table.clone(self.handlers) do
		if h.connected then
			runFn(h.fn, ...)
		end
	end
end
function SignalMT:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		resume(co, ...)
	end)
	return coroutine.yield()
end
M.newSignal = newSignal

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------
local Inst = {}
local InstMT = { __type = "Instance" }
local Methods = {}
local allTags = {}
local tagAdded, tagRemoved = {}, {}

local CLASS_DEFAULTS = {
	Part = { Size = v3(4, 1, 2), Transparency = 0, Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, Material = "Plastic" },
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, HipHeight = 2 },
	PointLight = { Enabled = true, Brightness = 1, Range = 8 },
	SpotLight = { Enabled = true, Brightness = 1, Range = 16 },
	SurfaceLight = { Enabled = true, Brightness = 1, Range = 16 },
	ProximityPrompt = { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10 },
	Sound = { Volume = 0.5, PlaybackSpeed = 1, Looped = false },
	Attachment = {},
}
local PART_CLASSES = { Part = true, TrussPart = true, SpawnLocation = true, WedgePart = true, MeshPart = true }
local EVENT_NAMES = {
	Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true, Destroying = true,
	AncestryChanged = true, Triggered = true, PromptButtonHoldBegan = true, PromptButtonHoldEnded = true, OnServerEvent = true,
	OnClientEvent = true, Event = true, Completed = true, CharacterAdded = true, CharacterRemoving = true, Died = true,
	Touched = true, MoveToFinished = true, PlayerAdded = true, PlayerRemoving = true, Heartbeat = true, Stepped = true,
	RenderStepped = true, Activated = true, MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true,
	InputChanged = true, Loaded = true, Blocked = true, PromptShown = true, PromptHidden = true, Destroying = true,
}

local function isA(self, className)
	local c = rawget(self, "ClassName")
	if c == className or className == "Instance" then
		return true
	end
	if className == "BasePart" and PART_CLASSES[c] then
		return true
	end
	if className == "Part" and (c == "SpawnLocation") then
		return true
	end
	if className == "Light" and (c == "PointLight" or c == "SpotLight" or c == "SurfaceLight") then
		return true
	end
	if className == "GuiObject" and (c == "Frame" or c == "TextLabel" or c == "TextButton" or c == "ScrollingFrame") then
		return true
	end
	if className == "GuiButton" and c == "TextButton" then
		return true
	end
	if className == "LuaSourceContainer" and (c == "Script" or c == "LocalScript" or c == "ModuleScript") then
		return true
	end
	return false
end

local function descendants(self, out)
	for _, c in rawget(self, "_children") do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local function isDescendantOf(self, ancestor)
	local p = rawget(self, "_props").Parent
	while p do
		if p == ancestor then
			return true
		end
		p = rawget(p, "_props").Parent
	end
	return false
end

local function signalFor(self, name)
	local signals = rawget(self, "_signals")
	local s = signals[name]
	if not s then
		s = newSignal()
		signals[name] = s
	end
	return s
end
M.signalFor = signalFor

local function partsOf(model)
	local list = {}
	if isA(model, "BasePart") then
		table.insert(list, model)
	end
	for _, d in descendants(model, {}) do
		if isA(d, "BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function getPivot(self)
	if isA(self, "BasePart") then
		return rawget(self, "_props").CFrame or CFrame.new()
	end
	local pp = rawget(self, "_props").PrimaryPart
	if pp then
		return rawget(pp, "_props").CFrame or CFrame.new()
	end
	for _, d in descendants(self, {}) do
		if isA(d, "BasePart") then
			local c = rawget(d, "_props").CFrame or CFrame.new()
			return CFrame.new(c.Position)
		end
	end
	return CFrame.new()
end

Methods.IsA = isA
Methods.GetChildren = function(self)
	return table.clone(rawget(self, "_children"))
end
Methods.GetDescendants = function(self)
	return descendants(self, {})
end
Methods.FindFirstChild = function(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, d in descendants(self, {}) do
			if rawget(d, "_props").Name == name then
				return d
			end
		end
	end
	return nil
end
Methods.WaitForChild = function(self, name)
	local c = Methods.FindFirstChild(self, name)
	if not c then
		record("WARN", "WaitForChild would yield forever: " .. Methods.GetFullName(self) .. "." .. tostring(name))
	end
	return c
end
Methods.FindFirstChildOfClass = function(self, className)
	for _, c in rawget(self, "_children") do
		if rawget(c, "ClassName") == className then
			return c
		end
	end
	return nil
end
Methods.FindFirstChildWhichIsA = function(self, className)
	for _, c in rawget(self, "_children") do
		if isA(c, className) then
			return c
		end
	end
	return nil
end
Methods.FindFirstAncestorOfClass = function(self, className)
	local p = rawget(self, "_props").Parent
	while p do
		if rawget(p, "ClassName") == className then
			return p
		end
		p = rawget(p, "_props").Parent
	end
	return nil
end
Methods.IsDescendantOf = isDescendantOf
Methods.GetFullName = function(self)
	local names = {}
	local cur = self
	while cur do
		table.insert(names, 1, rawget(cur, "_props").Name or "?")
		cur = rawget(cur, "_props").Parent
	end
	return table.concat(names, ".")
end
Methods.Destroy = function(self)
	signalFor(self, "Destroying"):Fire()
	self.Parent = nil
	for _, c in table.clone(rawget(self, "_children")) do
		Methods.Destroy(c)
	end
	rawset(self, "_destroyed", true)
end
Methods.ClearAllChildren = function(self)
	for _, c in table.clone(rawget(self, "_children")) do
		Methods.Destroy(c)
	end
end
Methods.Clone = function(self)
	local copy = Inst.new(rawget(self, "ClassName"))
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" then
			rawget(copy, "_props")[k] = v
		end
	end
	for _, c in rawget(self, "_children") do
		Methods.Clone(c).Parent = copy
	end
	return copy
end
Methods.SetAttribute = function(self, k, v)
	rawget(self, "_attrs")[k] = v
	local s = rawget(self, "_signals")["Attr_" .. k]
	if s then
		s:Fire()
	end
end
Methods.GetAttribute = function(self, k)
	return rawget(self, "_attrs")[k]
end
Methods.GetAttributes = function(self)
	return table.clone(rawget(self, "_attrs"))
end
Methods.GetAttributeChangedSignal = function(self, k)
	return signalFor(self, "Attr_" .. k)
end
Methods.GetPropertyChangedSignal = function(self, k)
	return signalFor(self, "Prop_" .. k)
end
Methods.GetPivot = getPivot
Methods.PivotTo = function(self, target)
	if isA(self, "BasePart") then
		self.CFrame = target
		return
	end
	local current = getPivot(self)
	local delta = target * current:Inverse()
	for _, p in partsOf(self) do
		local c = rawget(p, "_props").CFrame or CFrame.new()
		rawget(p, "_props").CFrame = delta * c
	end
end
Methods.GetBoundingBox = function(self)
	return getPivot(self), v3(4, 4, 4)
end
Methods.SetNetworkOwner = function() end
Methods.SetStateEnabled = function() end
Methods.MoveTo = function(self, pos)
	-- Humanoid:MoveTo: teleport the root part a few studs toward the goal per call
	local model = rawget(self, "_props").Parent
	local root = model and Methods.FindFirstChild(model, "HumanoidRootPart")
	if root then
		local c = rawget(root, "_props").CFrame
		local dir = pos - c.Position
		dir = v3(dir.X, 0, dir.Z)
		local step = math.min(dir.Magnitude, (rawget(self, "_props").WalkSpeed or 8) * 0.1)
		if step > 0.01 then
			local np = c.Position + dir.Unit * step
			Methods.PivotTo(model, CFrame.lookAt(np, np + dir.Unit))
			rawget(root, "_props").AssemblyLinearVelocity = dir.Unit * (rawget(self, "_props").WalkSpeed or 8)
		else
			rawget(root, "_props").AssemblyLinearVelocity = v3(0, 0, 0)
		end
	end
end
Methods.Play = function(self)
	rawget(self, "_props").IsPlaying = true
end
Methods.Stop = function(self)
	rawget(self, "_props").IsPlaying = false
end
Methods.FireClient = function(self, player, ...)
	M.clientEvents = M.clientEvents or {}
	table.insert(M.clientEvents, { remote = rawget(self, "_props").Name, player = player, args = table.pack(...) })
end
Methods.FireAllClients = function(self, ...)
	M.clientEvents = M.clientEvents or {}
	table.insert(M.clientEvents, { remote = rawget(self, "_props").Name, player = "ALL", args = table.pack(...) })
end
Methods.FireServer = function(self, ...)
	signalFor(self, "OnServerEvent"):Fire(M.localPlayer, ...)
end
Methods.LoadCharacter = function(self)
	M.spawnCharacter(self)
end
Methods.InputHoldBegin = function() end
Methods.InputHoldEnd = function() end
Methods.GetPlayers = function(self)
	local list = {}
	for _, c in rawget(self, "_children") do
		if rawget(c, "ClassName") == "Player" then
			table.insert(list, c)
		end
	end
	return list
end

InstMT.__index = function(self, k)
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	local m = Methods[k]
	if m then
		return m
	end
	if k == "ClassName" then
		return rawget(self, "ClassName")
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.Position
	end
	if k == "WorldPosition" then
		local parent = props.Parent
		local base = parent and rawget(parent, "_props").CFrame or CFrame.new()
		return base * (props.Position or v3())
	end
	if k == "PrimaryPart" or k == "RootPart" then
		if k == "RootPart" then
			local model = props.Parent
			return model and Methods.FindFirstChild(model, "HumanoidRootPart")
		end
		return nil
	end
	if k == "AssemblyLinearVelocity" then
		return v3()
	end
	if k == "Character" or k == "Parent" then
		return nil
	end
	if EVENT_NAMES[k] then
		return signalFor(self, k)
	end
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == k then
			return c
		end
	end
	local defaults = CLASS_DEFAULTS[rawget(self, "ClassName")]
	if defaults and defaults[k] ~= nil then
		return defaults[k]
	end
	return nil
end

InstMT.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old == v then
			return
		end
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		props.Parent = v
		if v then
			table.insert(rawget(v, "_children"), self)
			signalFor(v, "ChildAdded"):Fire(self)
			-- DescendantAdded on all ancestors
			local a = v
			while a do
				signalFor(a, "DescendantAdded"):Fire(self)
				a = rawget(a, "_props").Parent
			end
		end
		return
	end
	if k == "Position" and isA(self, "BasePart") then
		local c = props.CFrame or CFrame.new()
		props.CFrame = c + (v - c.Position)
		return
	end
	if k == "WorldPosition" then
		props.Position = v
		return
	end
	props[k] = v
	local s = rawget(self, "_signals")["Prop_" .. k]
	if s then
		s:Fire()
	end
	local changed = rawget(self, "_signals").Changed
	if changed and k == "Value" then
		changed:Fire(v)
	end
end
InstMT.__tostring = function(self)
	return rawget(self, "_props").Name or "Instance"
end

function Inst.new(className, parent)
	local o = setmetatable({ ClassName = className, _props = { Name = className }, _children = {}, _attrs = {}, _signals = {} }, InstMT)
	if PART_CLASSES[className] then
		rawget(o, "_props").CFrame = CFrame.new()
	end
	if className == "Attachment" then
		rawget(o, "_props").Position = v3()
	end
	if className == "NumberValue" then
		rawget(o, "_props").Value = 0
	end
	if parent then
		o.Parent = parent
	end
	M.instanceCount = (M.instanceCount or 0) + 1
	return o
end
Instance = { new = Inst.new }
M.Instance = Inst

--------------------------------------------------------------------------------
-- DataModel + services
--------------------------------------------------------------------------------
game = Inst.new("DataModel")
rawget(game, "_props").Name = "game"
local services = {}
local function service(name)
	local s = services[name]
	if not s then
		s = Inst.new(name)
		rawget(s, "_props").Name = name
		s.Parent = game
		services[name] = s
	end
	return s
end
Methods.GetService = function(_, name)
	return service(name)
end
workspace = service("Workspace")
local Workspace = workspace
rawget(game, "_props").PlaceId = 0
rawget(game, "_props").PrivateServerId = ""
rawget(game, "_props").JobId = "mock"
Methods.BindToClose = function() end
Methods.IsLoaded = function()
	return true
end

-- RunService
local RunService = service("RunService")
Methods.IsServer = function()
	return M.isServer ~= false
end
Methods.IsClient = function()
	return M.isServer == false
end
Methods.IsStudio = function()
	return true
end
Methods.BindToRenderStep = function() end

-- Workspace
Methods.Raycast = function()
	return nil
end
Methods.GetServerTimeNow = function()
	return M.now
end

-- CollectionService
Methods.AddTag = function(_, inst, tag)
	allTags[tag] = allTags[tag] or {}
	if not table.find(allTags[tag], inst) then
		table.insert(allTags[tag], inst)
		if tagAdded[tag] then
			tagAdded[tag]:Fire(inst)
		end
	end
end
Methods.RemoveTag = function(_, inst, tag)
	local list = allTags[tag]
	local i = list and table.find(list, inst)
	if i then
		table.remove(list, i)
	end
end
Methods.HasTag = function(_, inst, tag)
	return allTags[tag] ~= nil and table.find(allTags[tag], inst) ~= nil
end
Methods.GetTagged = function(_, tag)
	local out = {}
	for _, inst in allTags[tag] or {} do
		if not rawget(inst, "_destroyed") then
			table.insert(out, inst)
		end
	end
	return out
end
Methods.GetInstanceAddedSignal = function(_, tag)
	tagAdded[tag] = tagAdded[tag] or newSignal()
	return tagAdded[tag]
end
Methods.GetInstanceRemovedSignal = function(_, tag)
	tagRemoved[tag] = tagRemoved[tag] or newSignal()
	return tagRemoved[tag]
end

-- TweenService: applies the goal instantly
Methods.Create = function(_, obj, info, goal)
	local tween = {}
	tween.Completed = newSignal()
	function tween.Play()
		schedule(M.now + (info and info.Time or 0), function()
			if tween.cancelled then
				return
			end
			for k, v in goal do
				obj[k] = v
			end
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween.Cancel()
		tween.cancelled = true
	end
	tween.Pause = tween.Cancel
	return setmetatable(tween, {
		__index = function(_, k)
			if k == "Play" or k == "Cancel" or k == "Pause" then
				return function()
					tween[k]()
				end
			end
		end,
	})
end

-- PhysicsService
Methods.RegisterCollisionGroup = function() end
Methods.IsCollisionGroupRegistered = function()
	return false
end
Methods.CollisionGroupSetCollidable = function() end

-- DataStoreService: unavailable (like Studio without API access)
Methods.GetDataStore = function()
	local store = Inst.new("DataStore")
	return store
end
Methods.GetAsync = function()
	error("DataStore not available in mock")
end
Methods.UpdateAsync = function()
	error("DataStore not available in mock")
end

-- PathfindingService
Methods.CreatePath = function()
	local path = Inst.new("Path")
	rawget(path, "_props").Status = Enum.PathStatus.Success
	return path
end
Methods.ComputeAsync = function(self, a, b)
	rawget(self, "_props")._from = a
	rawget(self, "_props")._to = b
end
Methods.GetWaypoints = function(self)
	local a, b = rawget(self, "_props")._from or v3(), rawget(self, "_props")._to or v3()
	return { { Position = a }, { Position = a:Lerp(b, 0.5) }, { Position = b } }
end

-- Debris
Methods.AddItem = function(_, inst, life)
	schedule(M.now + (life or 10), function()
		if not rawget(inst, "_destroyed") then
			Methods.Destroy(inst)
		end
	end)
end

-- TeleportService
Methods.ReserveServer = function()
	error("Teleports are not available in the mock")
end

M.service = service
M.Methods = Methods
M.Workspace = Workspace
M.RunService = RunService
M.schedule = schedule
M.runFn = runFn

return M
