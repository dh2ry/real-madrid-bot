--==================================================================
-- 🏀 ملعب كرة السلة 1 ضد 1 + متجر — سكربت السيرفر
-- المكان: ServerScriptService  (نوعه Script عادي)
--
-- هذا السكربت يبني الماب كامل عند تشغيل اللعبة:
--   • ملعب سلة بالخطوط والسلتين والمدرجات والإضاءة ولوحات النتيجة
--   • منطقة انتظار فيها مربعين (أحمر وأزرق) للانضمام للمباراة
--   • متجر لبيع الكرات والقمصان
-- ويشغّل نظام المباراة: لاعبين، وقت محدد، ومن يسجل نقاط أكثر يفوز.
--==================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

------------------------------------------------------------------
-- ⚙️ الإعدادات (عدّلها براحتك)
------------------------------------------------------------------
local CONFIG = {
	MATCH_TIME = 120,        -- مدة المباراة بالثواني
	OVERTIME_TIME = 30,      -- وقت "السلة الذهبية" عند التعادل
	COUNTDOWN = 5,           -- العد التنازلي قبل البداية
	RESULTS_TIME = 6,        -- مدة عرض النتيجة بعد النهاية
	SHOT_CLOCK = 12,         -- أقصى وقت تمسك فيه الكرة بدون رمي

	START_COINS = 100,       -- عملات اللاعب الجديد
	COINS_PER_BASKET = 2,    -- عملات لكل سلة
	COINS_WIN = 50,          -- عملات الفوز
	COINS_LOSS = 15,         -- عملات المشاركة للخاسر
	COINS_DRAW = 25,         -- عملات التعادل

	STEAL_CHANCE = 0.4,      -- نسبة نجاح السرقة
	STEAL_RANGE = 7,         -- أقصى مسافة للسرقة
	STEAL_COOLDOWN = 1.5,    -- الانتظار بين محاولات السرقة

	BALL_GRAVITY = 80,       -- جاذبية الكرة (أقل = قوس أعلى وأبطأ)
	PERFECT_POWER = 0.85,    -- منتصف المنطقة الخضراء في عداد القوة
	PERFECT_WINDOW = 0.06,   -- نصف عرض المنطقة الخضراء

	DATASTORE_NAME = "Basketball1v1_v1",
}

------------------------------------------------------------------
-- 🛒 أغراض المتجر
------------------------------------------------------------------
local SHOP = {
	Balls = {
		{ Id = "classic", Name = "الكرة الكلاسيكية", Price = 0,
			Color = Color3.fromRGB(230, 110, 30), Material = Enum.Material.SmoothPlastic },
		{ Id = "royal", Name = "الكرة الملكية", Price = 150,
			Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.SmoothPlastic,
			Effect = "sparkles", EffectColor = Color3.fromRGB(255, 200, 60) },
		{ Id = "gold", Name = "الكرة الذهبية", Price = 300,
			Color = Color3.fromRGB(255, 195, 40), Material = Enum.Material.Metal },
		{ Id = "galaxy", Name = "كرة المجرة", Price = 450,
			Color = Color3.fromRGB(120, 60, 255), Material = Enum.Material.Neon,
			Effect = "sparkles", EffectColor = Color3.fromRGB(150, 220, 255) },
		{ Id = "fire", Name = "الكرة النارية", Price = 700,
			Color = Color3.fromRGB(255, 70, 20), Material = Enum.Material.Neon, Effect = "fire" },
	},
	Jerseys = {
		{ Id = "none", Name = "ملابسك الأصلية", Price = 0 },
		{ Id = "madrid", Name = "قميص مدريد الأبيض", Price = 200,
			Color = Color3.fromRGB(250, 250, 250), TextColor = Color3.fromRGB(212, 175, 55), Number = "7" },
		{ Id = "blue", Name = "القميص الأزرق", Price = 120,
			Color = Color3.fromRGB(30, 80, 200), TextColor = Color3.fromRGB(255, 255, 255), Number = "23" },
		{ Id = "black", Name = "القميص الأسود", Price = 120,
			Color = Color3.fromRGB(25, 25, 30), TextColor = Color3.fromRGB(255, 200, 60), Number = "24" },
		{ Id = "purple", Name = "القميص البنفسجي", Price = 250,
			Color = Color3.fromRGB(110, 40, 160), TextColor = Color3.fromRGB(255, 215, 0), Number = "10" },
		{ Id = "gold", Name = "القميص الذهبي", Price = 500,
			Color = Color3.fromRGB(230, 180, 30), TextColor = Color3.fromRGB(20, 20, 20), Number = "1" },
	},
}

local function findItem(category, id)
	local list = SHOP[category]
	if not list then
		return nil
	end
	for _, item in ipairs(list) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

------------------------------------------------------------------
-- 📐 مقاسات الملعب
------------------------------------------------------------------
local HALF_L, HALF_W = 47, 25        -- نصف طول/عرض الملعب (94 × 50)
local FLOOR_Y = 0.24                 -- ارتفاع سطح أرضية الملعب
local LINE_Y = FLOOR_Y + 0.02
local RIM_Y = 11                     -- ارتفاع الحلقة
local RIM_R = 1.75                   -- نصف قطر الحلقة
local BALL_SIZE = 1.5
local HOOP_X = 41.25                 -- بعد مركز الحلقة عن منتصف الملعب
local THREE_R = 21.5                 -- نصف قطر خط الثلاث نقاط
local THREE_CORNER_Z = 20

local LOBBY_CF = CFrame.lookAt(Vector3.new(-78, 4, 0), Vector3.new(0, 4, 0))
local SLOT_SPAWN = {
	[1] = CFrame.lookAt(Vector3.new(-14, 4, 0), Vector3.new(0, 4, 0)),
	[2] = CFrame.lookAt(Vector3.new(14, 4, 0), Vector3.new(0, 4, 0)),
}

local COLORS = {
	White = Color3.fromRGB(245, 245, 245),
	Wood = Color3.fromRGB(196, 140, 80),
	Paint = Color3.fromRGB(60, 40, 140),
	Gold = Color3.fromRGB(212, 175, 55),
	Navy = Color3.fromRGB(20, 30, 70),
	Purple = Color3.fromRGB(90, 50, 160),
	Red = Color3.fromRGB(220, 50, 50),
	Blue = Color3.fromRGB(40, 110, 230),
	Dark = Color3.fromRGB(40, 40, 45),
	Concrete = Color3.fromRGB(150, 150, 155),
	Green = Color3.fromRGB(70, 200, 90),
}

------------------------------------------------------------------
-- 📡 الريموتات (للتواصل مع سكربت اللاعب)
------------------------------------------------------------------
local oldRemotes = ReplicatedStorage:FindFirstChild("Basketball")
if oldRemotes then
	oldRemotes:Destroy()
end
local remotes = Instance.new("Folder")
remotes.Name = "Basketball"
remotes:SetAttribute("PerfectPower", CONFIG.PERFECT_POWER)
remotes:SetAttribute("PerfectWindow", CONFIG.PERFECT_WINDOW)
remotes.Parent = ReplicatedStorage

local function newRemote(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local ShootEvent = newRemote("RemoteEvent", "Shoot")
local StealEvent = newRemote("RemoteEvent", "Steal")
local NotifyEvent = newRemote("RemoteEvent", "Notify")
local OpenShopEvent = newRemote("RemoteEvent", "OpenShop")
local GetDataFn = newRemote("RemoteFunction", "GetData")
local BuyFn = newRemote("RemoteFunction", "Buy")
local EquipFn = newRemote("RemoteFunction", "Equip")

local function notify(plr, text, color)
	if plr and plr.Parent then
		NotifyEvent:FireClient(plr, text, color)
	end
end

local function notifyAll(text, color)
	NotifyEvent:FireAllClients(text, color)
end

------------------------------------------------------------------
-- 🧱 أدوات البناء
------------------------------------------------------------------
for _, name in ipairs({ "Baseplate", "SpawnLocation", "BasketballArena", "GameBall" }) do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local arena = Instance.new("Model")
arena.Name = "BasketballArena"
arena.Parent = workspace

local function newPart(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "ClassName" and k ~= "Shape" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or arena
	return p
end

local function newFolder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = arena
	return f
end

local function addSurfaceText(part, face, text, textColor, pixelsPerStud)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = pixelsPerStud or 40
	sg.LightInfluence = 0
	sg.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = sg
	return label, sg
end

local function addBillboard(part, text, color, offsetY, size, maxDistance)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromOffset(240, 60)
	bb.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	bb.MaxDistance = maxDistance or 120
	bb.LightInfluence = 0
	bb.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	return label
end

------------------------------------------------------------------
-- 🎨 مظهر الكرة (يُستخدم للكرة الحقيقية ولكرات العرض في المتجر)
------------------------------------------------------------------
local function applyBallSkin(ballPart, skinId)
	local skin = findItem("Balls", skinId) or SHOP.Balls[1]
	ballPart.Color = skin.Color
	ballPart.Material = skin.Material
	for _, c in ipairs(ballPart:GetChildren()) do
		if c:IsA("Fire") or c:IsA("Sparkles") then
			c:Destroy()
		end
	end
	if skin.Effect == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 0
		fire.Color = Color3.fromRGB(255, 120, 0)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 0)
		fire.Parent = ballPart
	elseif skin.Effect == "sparkles" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = skin.EffectColor or Color3.new(1, 1, 1)
		sparkles.Parent = ballPart
	end
end

------------------------------------------------------------------
-- 🏟️ الأرضية والملعب
------------------------------------------------------------------
newPart({ Name = "Ground", Size = Vector3.new(700, 1, 700), Position = Vector3.new(0, -0.5, 0),
	Color = Color3.fromRGB(70, 120, 60), Material = Enum.Material.Grass })
newPart({ Name = "Apron", Size = Vector3.new(110, 0.4, 66), Position = Vector3.new(0, 0, 0), Color = COLORS.Navy })
newPart({ Name = "CourtFloor", Size = Vector3.new(HALF_L * 2, 0.44, HALF_W * 2), Position = Vector3.new(0, 0.02, 0),
	Color = COLORS.Wood, Material = Enum.Material.WoodPlanks })

local linesFolder = newFolder("Lines")

local function courtLine(a, b, width)
	width = width or 0.35
	local pa = Vector3.new(a.X, LINE_Y, a.Z)
	local pb = Vector3.new(b.X, LINE_Y, b.Z)
	local len = (pb - pa).Magnitude
	if len < 0.01 then
		return
	end
	newPart({ Name = "Line", Size = Vector3.new(width, 0.04, len + width), CFrame = CFrame.lookAt((pa + pb) / 2, pb),
		Color = COLORS.White, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Parent = linesFolder })
end

local function courtArc(center, radius, a0, a1, segments)
	local prev
	for i = 0, segments do
		local a = a0 + (a1 - a0) * i / segments
		local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		if prev then
			courtLine(prev, p, 0.3)
		end
		prev = p
	end
end

-- حدود الملعب وخط المنتصف
courtLine(Vector3.new(-HALF_L, 0, -HALF_W), Vector3.new(HALF_L, 0, -HALF_W))
courtLine(Vector3.new(-HALF_L, 0, HALF_W), Vector3.new(HALF_L, 0, HALF_W))
courtLine(Vector3.new(-HALF_L, 0, -HALF_W), Vector3.new(-HALF_L, 0, HALF_W))
courtLine(Vector3.new(HALF_L, 0, -HALF_W), Vector3.new(HALF_L, 0, HALF_W))
courtLine(Vector3.new(0, 0, -HALF_W), Vector3.new(0, 0, HALF_W))

-- دائرة المنتصف
newPart({ Name = "CenterCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.02, 12, 12),
	CFrame = CFrame.new(0, FLOOR_Y + 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = COLORS.Paint, CanCollide = false, CanQuery = false, CastShadow = false, Parent = linesFolder })
courtArc(Vector3.new(0, 0, 0), 6, 0, math.pi * 2, 32)
local centerText = newPart({ Name = "CenterText", Size = Vector3.new(9, 0.05, 4), Position = Vector3.new(0, FLOOR_Y + 0.05, 0),
	Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = linesFolder })
addSurfaceText(centerText, Enum.NormalId.Top, "1 ضد 1", COLORS.Gold, 30)

-- منطقة الرسم وخط الرمية الحرة وخط الثلاث نقاط (لكل جهة)
local cornerX = math.sqrt(THREE_R ^ 2 - THREE_CORNER_Z ^ 2)
local threePhi = math.asin(THREE_CORNER_Z / THREE_R)
for _, s in ipairs({ 1, -1 }) do
	newPart({ Name = "Paint", Size = Vector3.new(19, 0.02, 12), Position = Vector3.new(s * (HALF_L - 9.5), FLOOR_Y + 0.01, 0),
		Color = COLORS.Paint, CanCollide = false, CanQuery = false, CastShadow = false, Parent = linesFolder })
	local ftX = s * (HALF_L - 19)
	courtLine(Vector3.new(s * HALF_L, 0, -6), Vector3.new(ftX, 0, -6))
	courtLine(Vector3.new(s * HALF_L, 0, 6), Vector3.new(ftX, 0, 6))
	courtLine(Vector3.new(ftX, 0, -6), Vector3.new(ftX, 0, 6))
	courtArc(Vector3.new(ftX, 0, 0), 6, 0, math.pi * 2, 28)

	local rimFloor = Vector3.new(s * HOOP_X, 0, 0)
	local cx = s * (HOOP_X - cornerX)
	courtLine(Vector3.new(s * HALF_L, 0, -THREE_CORNER_Z), Vector3.new(cx, 0, -THREE_CORNER_Z))
	courtLine(Vector3.new(s * HALF_L, 0, THREE_CORNER_Z), Vector3.new(cx, 0, THREE_CORNER_Z))
	local base = (s == 1) and math.pi or 0
	courtArc(rimFloor, THREE_R, base - threePhi, base + threePhi, 30)
end

------------------------------------------------------------------
-- 🏀 السلتين
------------------------------------------------------------------
local hoops = {}

local function buildHoop(s)
	local folder = newFolder(s == 1 and "HoopEast" or "HoopWest")
	local center = Vector3.new(s * HOOP_X, RIM_Y, 0)

	-- الحلقة: قطع صغيرة على شكل دائرة (الكرة ترتد منها فعلياً)
	local ring = {}
	local segments = 16
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * RIM_R, 0, math.sin(a) * RIM_R)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local seg = newPart({ Name = "Rim", Size = Vector3.new(0.2, 0.2, (2 * math.pi * RIM_R / segments) * 1.1),
			CFrame = CFrame.lookAt(p, p + tangent), Color = Color3.fromRGB(240, 90, 20),
			Material = Enum.Material.Metal, Parent = folder })
		table.insert(ring, seg)
	end

	-- الشبكة (شكلية فقط، الكرة تمر من خلالها)
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		local top = center + Vector3.new(math.cos(a) * RIM_R, -0.1, math.sin(a) * RIM_R)
		local bottom = center + Vector3.new(math.cos(a + 0.4) * 1.1, -1.7, math.sin(a + 0.4) * 1.1)
		newPart({ Name = "Net", Size = Vector3.new(0.06, 0.06, (bottom - top).Magnitude),
			CFrame = CFrame.lookAt((top + bottom) / 2, bottom), Color = COLORS.White,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = folder })
	end

	-- اللوحة الخلفية
	local boardX = s * (HOOP_X + RIM_R + 0.35)
	newPart({ Name = "Backboard", Size = Vector3.new(0.3, 4.2, 7), Position = Vector3.new(boardX, RIM_Y + 1.6, 0),
		Color = COLORS.White, Transparency = 0.35, Material = Enum.Material.Glass, Parent = folder })
	local frontX = boardX - s * 0.17
	local function boardLine(size, pos)
		newPart({ Name = "BoardMark", Size = size, Position = pos, Color = COLORS.Red,
			CanCollide = false, CanQuery = false, Parent = folder })
	end
	boardLine(Vector3.new(0.05, 0.12, 2.4), Vector3.new(frontX, RIM_Y + 0.25, 0))
	boardLine(Vector3.new(0.05, 0.12, 2.4), Vector3.new(frontX, RIM_Y + 1.85, 0))
	boardLine(Vector3.new(0.05, 1.7, 0.12), Vector3.new(frontX, RIM_Y + 1.05, -1.15))
	boardLine(Vector3.new(0.05, 1.7, 0.12), Vector3.new(frontX, RIM_Y + 1.05, 1.15))

	-- قاعدة تثبيت الحلقة + العمود
	newPart({ Name = "RimBracket", Size = Vector3.new(0.5, 0.25, 0.6),
		Position = Vector3.new(s * (HOOP_X + RIM_R + 0.05), RIM_Y, 0), Color = Color3.fromRGB(240, 90, 20),
		Material = Enum.Material.Metal, Parent = folder })
	newPart({ Name = "Arm", Size = Vector3.new(5, 0.6, 0.6), Position = Vector3.new(s * 46, RIM_Y + 1.6, 0),
		Color = COLORS.Dark, Material = Enum.Material.Metal, Parent = folder })
	local poleH = RIM_Y + 2.2
	newPart({ Name = "Pole", Size = Vector3.new(1, poleH, 1), Position = Vector3.new(s * 48.5, poleH / 2, 0),
		Color = COLORS.Dark, Material = Enum.Material.Metal, Parent = folder })
	newPart({ Name = "PolePad", Size = Vector3.new(2, 5, 2), Position = Vector3.new(s * 48.7, 2.5, 0),
		Color = COLORS.Purple, Parent = folder })

	return { Side = s, Center = center, Ring = ring }
end

hoops[1] = buildHoop(1)    -- يهاجمها اللاعب 1 (الأحمر)
hoops[-1] = buildHoop(-1)  -- يهاجمها اللاعب 2 (الأزرق)

local function hoopForSlot(i)
	return hoops[i == 1 and 1 or -1]
end

local function flashHoop(hoop)
	for _, seg in ipairs(hoop.Ring) do
		seg.Color = COLORS.Gold
		seg.Material = Enum.Material.Neon
	end
	task.delay(0.8, function()
		for _, seg in ipairs(hoop.Ring) do
			seg.Color = Color3.fromRGB(240, 90, 20)
			seg.Material = Enum.Material.Metal
		end
	end)
end

------------------------------------------------------------------
-- 🪑 المدرجات والإضاءة ولوحات النتيجة
------------------------------------------------------------------
local standsFolder = newFolder("Stands")
local boardRefs = {}

local function makeScoreboard(pos)
	local board = newPart({ Name = "Scoreboard", Size = Vector3.new(30, 10, 1),
		CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), Color = Color3.fromRGB(15, 15, 20), Parent = standsFolder })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = board
	local function lbl(x, y, w, h, color)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(x, y)
		l.Size = UDim2.fromScale(w, h)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = color
		l.Text = ""
		l.Parent = sg
		return l
	end
	table.insert(boardRefs, {
		P1Name = lbl(0.02, 0.06, 0.34, 0.22, COLORS.Red),
		Score1 = lbl(0.02, 0.3, 0.34, 0.62, COLORS.Red),
		P2Name = lbl(0.64, 0.06, 0.34, 0.22, COLORS.Blue),
		Score2 = lbl(0.64, 0.3, 0.34, 0.62, COLORS.Blue),
		Time = lbl(0.38, 0.12, 0.24, 0.42, COLORS.Gold),
		Status = lbl(0.38, 0.6, 0.24, 0.25, COLORS.White),
	})
end

for _, t in ipairs({ 1, -1 }) do
	for row = 0, 5 do
		local h = 1 + row * 1.6
		newPart({ Name = "StandRow", Size = Vector3.new(96, h, 3), Position = Vector3.new(0, h / 2, t * (30 + row * 3)),
			Color = (row % 2 == 0) and COLORS.White or COLORS.Purple, Parent = standsFolder })
	end
	for x = -44, 44, 4 do
		local p = Vector3.new(x, 1.5, t * 30)
		newPart({ ClassName = "Seat", Name = "Seat", Size = Vector3.new(2, 1, 2), CFrame = CFrame.lookAt(p, Vector3.new(x, 1.5, 0)),
			Color = (x % 8 == 0) and COLORS.Red or COLORS.Blue, Parent = standsFolder })
	end
	local wallPos = Vector3.new(0, 7, t * 47.5)
	local wall = newPart({ Name = "BackWall", Size = Vector3.new(96, 14, 1), CFrame = CFrame.lookAt(wallPos, Vector3.new(0, 7, 0)),
		Color = COLORS.Navy, Parent = standsFolder })
	addSurfaceText(wall, Enum.NormalId.Front, "🏀 ساحة السلة الملكية 🏀", COLORS.Gold, 8)
	makeScoreboard(Vector3.new(0, 19, t * 47.5))
end

for _, x in ipairs({ -55, 55 }) do
	for _, z in ipairs({ -30, 30 }) do
		newPart({ Name = "LightPole", Size = Vector3.new(1.2, 30, 1.2), Position = Vector3.new(x, 15, z),
			Color = COLORS.Dark, Material = Enum.Material.Metal, Parent = standsFolder })
		local lampPos = Vector3.new(x, 30.5, z)
		local lamp = newPart({ Name = "Lamp", Size = Vector3.new(5, 3, 1), CFrame = CFrame.lookAt(lampPos, Vector3.new(0, 0, 0)),
			Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, Parent = standsFolder })
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 60
		light.Angle = 70
		light.Brightness = 3
		light.Parent = lamp
	end
end

------------------------------------------------------------------
-- 🚪 منطقة الانتظار (Spawn + مربعات الانضمام)
------------------------------------------------------------------
local lobbyFolder = newFolder("Lobby")
newPart({ Name = "LobbyFloor", Size = Vector3.new(36, 0.4, 90), Position = Vector3.new(-74, 0, 0),
	Color = COLORS.Concrete, Material = Enum.Material.Concrete, Parent = lobbyFolder })

local spawnPos = Vector3.new(-80, 0.45, 0)
newPart({ ClassName = "SpawnLocation", Name = "SpawnLocation", Size = Vector3.new(8, 0.5, 8),
	CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(1, 0, 0)), Color = COLORS.Gold,
	Neutral = true, Duration = 0, Parent = workspace })

local pads = {}
local padLabels = {}
for i, z in ipairs({ -8, 8 }) do
	local pad = newPart({ Name = "JoinPad" .. i, Size = Vector3.new(7, 0.5, 7), Position = Vector3.new(-60, 0.45, z),
		Color = (i == 1) and COLORS.Red or COLORS.Blue, Material = Enum.Material.Neon, Parent = lobbyFolder })
	pads[i] = pad
	padLabels[i] = addBillboard(pad, "", COLORS.White, 4, UDim2.fromOffset(260, 70), 90)
end

local infoPos = Vector3.new(-66, 7.5, 0)
local infoSign = newPart({ Name = "InfoSign", Size = Vector3.new(12, 5, 0.5),
	CFrame = CFrame.lookAt(infoPos, infoPos + Vector3.new(-1, 0, 0)), Color = COLORS.Navy, Parent = lobbyFolder })
addSurfaceText(infoSign, Enum.NormalId.Front,
	string.format("🏀 مباراة 1 ضد 1\nقف على المربع الأحمر أو الأزرق\nمن يسجّل أكثر خلال %d ثانية يفوز!", CONFIG.MATCH_TIME),
	COLORS.White, 30)
for _, z in ipairs({ -5.5, 5.5 }) do
	newPart({ Name = "SignPost", Size = Vector3.new(0.5, 10, 0.5), Position = Vector3.new(-66, 5, z),
		Color = COLORS.Dark, Parent = lobbyFolder })
end

------------------------------------------------------------------
-- 🛒 مبنى المتجر
------------------------------------------------------------------
local shopFolder = newFolder("Shop")
local SHOP_X, SHOP_Z = -74, 32
newPart({ Name = "ShopFloor", Size = Vector3.new(22, 0.3, 16), Position = Vector3.new(SHOP_X, 0.35, SHOP_Z),
	Color = Color3.fromRGB(230, 225, 210), Material = Enum.Material.Marble, Parent = shopFolder })
newPart({ Name = "ShopBackWall", Size = Vector3.new(22, 12, 1), Position = Vector3.new(SHOP_X, 6.5, SHOP_Z + 7.5),
	Color = COLORS.White, Parent = shopFolder })
newPart({ Name = "ShopWallL", Size = Vector3.new(1, 12, 16), Position = Vector3.new(SHOP_X - 10.5, 6.5, SHOP_Z),
	Color = COLORS.White, Parent = shopFolder })
newPart({ Name = "ShopWallR", Size = Vector3.new(1, 12, 16), Position = Vector3.new(SHOP_X + 10.5, 6.5, SHOP_Z),
	Color = COLORS.White, Parent = shopFolder })
newPart({ Name = "ShopRoof", Size = Vector3.new(24, 1, 18), Position = Vector3.new(SHOP_X, 13, SHOP_Z),
	Color = COLORS.Purple, Parent = shopFolder })

local signPos = Vector3.new(SHOP_X, 15, SHOP_Z - 7.5)
local shopSign = newPart({ Name = "ShopSign", Size = Vector3.new(14, 3, 0.6),
	CFrame = CFrame.lookAt(signPos, signPos + Vector3.new(0, 0, -1)), Color = COLORS.Navy, Parent = shopFolder })
addSurfaceText(shopSign, Enum.NormalId.Front, "🛒 المتجر", COLORS.Gold, 30)

local counter = newPart({ Name = "Counter", Size = Vector3.new(12, 3.5, 2), Position = Vector3.new(SHOP_X, 2.25, SHOP_Z - 1),
	Color = Color3.fromRGB(120, 80, 45), Material = Enum.Material.Wood, Parent = shopFolder })
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "افتح المتجر"
prompt.ObjectText = "المتجر"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = counter
prompt.Triggered:Connect(function(plr)
	OpenShopEvent:FireClient(plr)
end)

local function priceText(item)
	return item.Price == 0 and "مجاني" or (tostring(item.Price) .. " 🪙")
end

-- كرات العرض على الطاولات
for i, item in ipairs(SHOP.Balls) do
	local x = SHOP_X - 8 + (i - 1) * 4
	newPart({ Name = "Pedestal", Size = Vector3.new(1.6, 3, 1.6), Position = Vector3.new(x, 2, SHOP_Z + 5.5),
		Color = COLORS.Navy, Parent = shopFolder })
	local display = newPart({ Name = "DisplayBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5),
		Position = Vector3.new(x, 4.25, SHOP_Z + 5.5), CanCollide = false, Parent = shopFolder })
	applyBallSkin(display, item.Id)
	addBillboard(display, item.Name .. "\n" .. priceText(item), COLORS.White, 1.8, UDim2.fromOffset(130, 44), 40)
end

-- القمصان على الجدار
local jerseyIndex = 0
for _, item in ipairs(SHOP.Jerseys) do
	if item.Id ~= "none" then
		jerseyIndex += 1
		local p = Vector3.new(SHOP_X - 8 + (jerseyIndex - 1) * 4, 8.5, SHOP_Z + 6.9)
		local shirt = newPart({ Name = "DisplayJersey", Size = Vector3.new(2.6, 3, 0.2),
			CFrame = CFrame.lookAt(p, p + Vector3.new(0, 0, -1)), Color = item.Color, Parent = shopFolder })
		addSurfaceText(shirt, Enum.NormalId.Front, item.Number, item.TextColor, 40)
		addBillboard(shirt, item.Name .. "\n" .. priceText(item), COLORS.White, 2.4, UDim2.fromOffset(130, 44), 40)
	end
end

------------------------------------------------------------------
-- 💾 بيانات اللاعبين (عملات، فوز، المشتريات)
------------------------------------------------------------------
local store
pcall(function()
	store = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
end)

local profiles = {}

local function defaultProfile()
	return {
		Coins = CONFIG.START_COINS,
		Wins = 0,
		Balls = { classic = true },
		Jerseys = { none = true },
		EquippedBall = "classic",
		EquippedJersey = "none",
	}
end

local function updateLeaderstats(plr)
	local prof = profiles[plr]
	local ls = plr:FindFirstChild("leaderstats")
	if not prof or not ls then
		return
	end
	ls["عملات"].Value = prof.Coins
	ls["فوز"].Value = prof.Wins
end

local function addCoins(plr, amount)
	local prof = plr and profiles[plr]
	if not prof then
		return
	end
	prof.Coins = math.max(0, prof.Coins + amount)
	updateLeaderstats(plr)
end

local function saveProfile(plr)
	local prof = profiles[plr]
	if not store or not prof then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("u_" .. plr.UserId, prof)
	end)
	if not ok then
		warn("[Basketball] فشل حفظ بيانات " .. plr.Name .. ": " .. tostring(err))
	end
end

local function loadProfile(plr)
	local prof = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("u_" .. plr.UserId)
		end)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				prof[k] = v
			end
			prof.Balls.classic = true
			prof.Jerseys.none = true
		elseif not ok then
			warn("[Basketball] تعذر تحميل البيانات (فعّل API Services للحفظ): " .. tostring(data))
		end
	end
	profiles[plr] = prof
	updateLeaderstats(plr)
end

local function waitForProfile(plr)
	local start = os.clock()
	while not profiles[plr] and plr.Parent and os.clock() - start < 10 do
		task.wait(0.1)
	end
	return profiles[plr]
end

------------------------------------------------------------------
-- 👕 تطبيق القميص على الشخصية
------------------------------------------------------------------
local TORSO_PARTS = { "UpperTorso", "LowerTorso", "Torso" }

local function applyJersey(plr)
	local char = plr.Character
	local prof = profiles[plr]
	if not char or not prof then
		return
	end
	local item = findItem("Jerseys", prof.EquippedJersey)

	-- نحفظ الملابس الأصلية في مجلد عشان نقدر نرجعها
	local backup = char:FindFirstChild("OriginalClothes")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "OriginalClothes"
		backup.Parent = char
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d.Name == "JerseyGui" then
			d:Destroy()
		end
	end

	if not item or item.Id == "none" then
		for _, c in ipairs(backup:GetChildren()) do
			c.Parent = char
		end
		for _, name in ipairs(TORSO_PARTS) do
			local part = char:FindFirstChild(name)
			if part and part:GetAttribute("OrigColor") then
				part.Color = part:GetAttribute("OrigColor")
			end
		end
		return
	end

	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Shirt") or c:IsA("ShirtGraphic") then
			c.Parent = backup
		end
	end
	for _, name in ipairs(TORSO_PARTS) do
		local part = char:FindFirstChild(name)
		if part then
			if part:GetAttribute("OrigColor") == nil then
				part:SetAttribute("OrigColor", part.Color)
			end
			part.Color = item.Color
			if name ~= "LowerTorso" then
				for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front }) do
					local label, sg = addSurfaceText(part, face, item.Number, item.TextColor, 50)
					sg.Name = "JerseyGui"
					if face == Enum.NormalId.Front then
						label.Size = UDim2.fromScale(0.5, 0.5)
						label.Position = UDim2.fromScale(0.25, 0.2)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------
-- 🏀 الكرة
------------------------------------------------------------------
local ball = Instance.new("Part")
ball.Name = "GameBall"
ball.Shape = Enum.PartType.Ball
ball.Size = Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE)
ball.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.4, 0.8, 1, 100)
ball.TopSurface = Enum.SurfaceType.Smooth
ball.BottomSurface = Enum.SurfaceType.Smooth
ball.Position = Vector3.new(0, 6, 0)
ball:SetAttribute("HolderId", 0)
ball:SetAttribute("ShotDeadline", 0)
ball.Parent = workspace
applyBallSkin(ball, "classic")

-- قوة ترفع الكرة جزئياً عشان يكون قوس الرمية جميل (جاذبية أخف للكرة فقط)
local ballAttachment = Instance.new("Attachment")
ballAttachment.Parent = ball
local antiGravity = Instance.new("VectorForce")
antiGravity.Attachment0 = ballAttachment
antiGravity.RelativeTo = Enum.ActuatorRelativeTo.World
antiGravity.ApplyAtCenterOfMass = true
antiGravity.Force = Vector3.new(0, ball:GetMass() * (workspace.Gravity - CONFIG.BALL_GRAVITY), 0)
antiGravity.Parent = ball

local ballState = {
	Holder = nil,
	HeldSince = 0,
	StealProtect = 0,
	Locked = false,
	LastShot = nil,
	LastToucher = nil,
	LooseSince = os.clock(),
	NoPickup = {},
	StealCooldown = {},
	PrevPos = ball.Position,
}

local function setBallOwnerServer()
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
end
setBallOwnerServer()

local function releaseBall()
	local weld = ball:FindFirstChild("HoldWeld")
	if weld then
		weld:Destroy()
	end
	ball.Massless = false
	ball.CanCollide = true
	antiGravity.Enabled = true
	ballState.Holder = nil
	ballState.LooseSince = os.clock()
	ball:SetAttribute("HolderId", 0)
	ball:SetAttribute("ShotDeadline", 0)
	setBallOwnerServer()
end

local function resetBallCenter()
	releaseBall()
	ballState.LastToucher = nil
	ballState.LastShot = nil
	ball.CFrame = CFrame.new(0, 9, 0)
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
end

local Match -- (معرّف تحت)

local function isMatchLive()
	return Match.State == "Playing" or Match.State == "Overtime"
end

local function slotIndex(plr)
	if not plr then
		return nil
	end
	if Match.Slots[1] == plr then
		return 1
	elseif Match.Slots[2] == plr then
		return 2
	end
	return nil
end

local function giveBall(plr)
	local char = plr and plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		resetBallCenter()
		return
	end
	releaseBall()
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CanCollide = false
	ball.Massless = true
	antiGravity.Enabled = false
	ball.CFrame = hrp.CFrame * CFrame.new(0.9, -0.2, -1.6)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HoldWeld"
	weld.Part0 = hrp
	weld.Part1 = ball
	weld.Parent = ball

	ballState.Holder = plr
	ballState.HeldSince = os.clock()
	ballState.StealProtect = os.clock() + 0.8
	ballState.LastToucher = plr
	ball:SetAttribute("HolderId", plr.UserId)
	ball:SetAttribute("ShotDeadline", isMatchLive() and (workspace:GetServerTimeNow() + CONFIG.SHOT_CLOCK) or 0)
	local prof = profiles[plr]
	applyBallSkin(ball, prof and prof.EquippedBall or "classic")
end

local function canTouchBall(plr)
	if Match.State == "Waiting" then
		return true
	end
	if isMatchLive() then
		return slotIndex(plr) ~= nil
	end
	return false
end

local function playerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local plr = Players:GetPlayerFromCharacter(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if plr and hum and hum.Health > 0 then
		return plr
	end
	return nil
end

ball.Touched:Connect(function(hit)
	if ballState.Holder or ballState.Locked then
		return
	end
	local plr = playerFromHit(hit)
	if not plr or not canTouchBall(plr) then
		return
	end
	local blockedUntil = ballState.NoPickup[plr]
	if blockedUntil and os.clock() < blockedUntil then
		return
	end
	giveBall(plr)
end)

------------------------------------------------------------------
-- 🎯 الرمي
------------------------------------------------------------------
local rng = Random.new()

local function targetHoopFor(plr, pos)
	local idx = isMatchLive() and slotIndex(plr)
	if idx then
		return hoopForSlot(idx)
	end
	return hoops[pos.X >= 0 and 1 or -1]
end

ShootEvent.OnServerEvent:Connect(function(plr, power)
	if ballState.Holder ~= plr then
		return
	end
	if typeof(power) ~= "number" or power ~= power then
		return
	end
	power = math.clamp(power, 0, 1)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local hoop = targetHoopFor(plr, hrp.Position)
	local rim = hoop.Center
	local start = hrp.Position + Vector3.new(0, 2.5, 0)
	local flat = Vector3.new(rim.X - start.X, 0, rim.Z - start.Z)
	local dist = flat.Magnitude
	local dir = dist > 0.01 and flat.Unit or Vector3.new(hoop.Side, 0, 0)
	start += dir * 1.2

	-- الدقة: كل ما بعدت عن المنطقة الخضراء كل ما زاد الخطأ
	local diff = power - CONFIG.PERFECT_POWER
	local err = math.max(0, math.abs(diff) - CONFIG.PERFECT_WINDOW) * 9
	local sideDir = Vector3.new(-dir.Z, 0, dir.X)
	local lateral = (rng:NextNumber() - 0.5) * (dist * 0.025 + err * 0.6)
	local target = rim + dir * (math.sign(diff) * err) + sideDir * lateral

	-- نحسب السرعة اللازمة عشان الكرة توصل للهدف بقوس
	local T = 0.55 + dist * 0.022
	local g = CONFIG.BALL_GRAVITY
	local d = target - start
	local velocity = Vector3.new(d.X / T, (d.Y + 0.5 * g * T * T) / T, d.Z / T)

	local rimFlat = Vector3.new(rim.X, 0, rim.Z)
	local posFlat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	local isThree = (posFlat - rimFlat).Magnitude > THREE_R or math.abs(hrp.Position.Z) > THREE_CORNER_Z

	releaseBall()
	ball.CFrame = CFrame.new(start)
	ball.AssemblyLinearVelocity = velocity
	ball.AssemblyAngularVelocity = sideDir * -8
	ballState.LastShot = { Shooter = plr, Points = isThree and 3 or 2, Time = os.clock() }
	ballState.LastToucher = plr
	ballState.NoPickup[plr] = os.clock() + 0.6
end)

------------------------------------------------------------------
-- 🥷 السرقة
------------------------------------------------------------------
StealEvent.OnServerEvent:Connect(function(plr)
	if not (Match.State == "Waiting" or (isMatchLive() and slotIndex(plr))) then
		return
	end
	local now = os.clock()
	if (ballState.StealCooldown[plr] or 0) > now then
		return
	end
	ballState.StealCooldown[plr] = now + CONFIG.STEAL_COOLDOWN
	local holder = ballState.Holder
	if not holder or holder == plr or now < ballState.StealProtect then
		return
	end
	local myHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local hisHrp = holder.Character and holder.Character:FindFirstChild("HumanoidRootPart")
	if not myHrp or not hisHrp or (myHrp.Position - hisHrp.Position).Magnitude > CONFIG.STEAL_RANGE then
		notify(plr, "اقترب أكثر عشان تسرق الكرة", COLORS.Red)
		return
	end
	if rng:NextNumber() < CONFIG.STEAL_CHANCE then
		giveBall(plr)
		notify(plr, "🥷 سرقت الكرة!", COLORS.Green)
		notify(holder, "انسرقت منك الكرة!", COLORS.Red)
	else
		notify(plr, "فشلت محاولة السرقة", COLORS.Red)
	end
end)

------------------------------------------------------------------
-- 🏆 نظام المباراة
------------------------------------------------------------------
Match = {
	State = "Waiting",
	Slots = {},
	Scores = { 0, 0 },
	TimeLeft = CONFIG.MATCH_TIME,
	Message = "",
}

local STATE_TEXT = {
	Waiting = "بانتظار لاعبين",
	Countdown = "استعداد...",
	Playing = "المباراة جارية",
	Overtime = "السلة الذهبية!",
	Ended = "انتهت المباراة",
}

local function refresh()
	local n1 = Match.Slots[1] and Match.Slots[1].DisplayName or "—"
	local n2 = Match.Slots[2] and Match.Slots[2].DisplayName or "—"
	remotes:SetAttribute("State", Match.State)
	remotes:SetAttribute("TimeLeft", Match.TimeLeft)
	remotes:SetAttribute("Score1", Match.Scores[1])
	remotes:SetAttribute("Score2", Match.Scores[2])
	remotes:SetAttribute("P1Name", n1)
	remotes:SetAttribute("P2Name", n2)
	remotes:SetAttribute("Message", Match.Message)

	local t = math.max(0, Match.TimeLeft)
	local timeText = string.format("%d:%02d", t // 60, t % 60)
	for _, refs in ipairs(boardRefs) do
		refs.P1Name.Text = n1
		refs.P2Name.Text = n2
		refs.Score1.Text = tostring(Match.Scores[1])
		refs.Score2.Text = tostring(Match.Scores[2])
		refs.Time.Text = timeText
		refs.Status.Text = STATE_TEXT[Match.State] or ""
	end

	for i = 1, 2 do
		local plr = Match.Slots[i]
		local tag = (i == 1) and "🔴 اللاعب 1" or "🔵 اللاعب 2"
		padLabels[i].Text = plr and (tag .. "\n" .. plr.DisplayName) or (tag .. "\nقف هنا للعب")
	end
end

local function setState(state, message)
	Match.State = state
	Match.Message = message or ""
	refresh()
end

-- الانضمام عن طريق الوقوف على المربع
for i, pad in ipairs(pads) do
	pad.Touched:Connect(function(hit)
		if Match.State ~= "Waiting" then
			return
		end
		local plr = playerFromHit(hit)
		if not plr or slotIndex(plr) or Match.Slots[i] then
			return
		end
		Match.Slots[i] = plr
		notify(plr, "انضممت كلاعب " .. i .. "! انتظر خصمك 🏀", COLORS.Gold)
		refresh()
	end)
end

local function validateSlots()
	for i = 1, 2 do
		local plr = Match.Slots[i]
		if plr then
			local hrp = plr.Parent and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local padPos = pads[i].Position
			local offPad = not hrp
				or Vector2.new(hrp.Position.X - padPos.X, hrp.Position.Z - padPos.Z).Magnitude > 6
			if offPad then
				Match.Slots[i] = nil
				notify(plr, "خرجت من المربع، تم إلغاء انضمامك", COLORS.Red)
			end
		end
	end
	refresh()
end

local function teleport(plr, cf)
	local char = plr and plr.Character
	if char and char.PrimaryPart then
		char:PivotTo(cf)
	end
end

local function kickSpectatorsOffCourt()
	for _, plr in ipairs(Players:GetPlayers()) do
		if not slotIndex(plr) then
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local p = hrp.Position
				if math.abs(p.X) < HALF_L + 2 and math.abs(p.Z) < HALF_W + 2 and p.Y < 20 then
					teleport(plr, LOBBY_CF)
					notify(plr, "الملعب مشغول بمباراة، تفرّج من المدرجات 🍿", COLORS.Gold)
				end
			end
		end
	end
end

local function checkLiveBall()
	local holder = ballState.Holder
	if holder then
		if os.clock() - ballState.HeldSince > CONFIG.SHOT_CLOCK then
			local idx = slotIndex(holder)
			local other = idx and Match.Slots[3 - idx]
			if other then
				notifyAll("⏱️ انتهى وقت الهجمة! الكرة لـ " .. other.DisplayName, COLORS.Gold)
				giveBall(other)
			end
		end
		return
	end
	if ballState.Locked then
		return
	end
	local p = ball.Position
	local outside = math.abs(p.X) > HALF_L + 0.5 or math.abs(p.Z) > HALF_W + 0.5
	local resting = p.Y < FLOOR_Y + 3 or ball.AssemblyLinearVelocity.Magnitude < 2
	local stale = os.clock() - ballState.LooseSince > 10
	if (outside and resting) or p.Y < -20 or stale then
		local idx = slotIndex(ballState.LastToucher)
		local other = idx and Match.Slots[3 - idx]
		if other and other.Parent then
			notifyAll("🚫 خرجت الكرة! الاستحواذ لـ " .. other.DisplayName, COLORS.Gold)
			giveBall(other)
		else
			resetBallCenter()
		end
	end
end

local function onBasket(hoop)
	flashHoop(hoop)
	local shot = ballState.LastShot
	local recentShooter = shot and (os.clock() - shot.Time < 4) and shot.Shooter or nil
	ballState.LastShot = nil

	if isMatchLive() then
		local idx = (hoop.Side == 1) and 1 or 2
		local scorer = Match.Slots[idx]
		if not scorer then
			return
		end
		local points = (recentShooter == scorer and shot) and shot.Points or 2
		Match.Scores[idx] += points
		addCoins(scorer, CONFIG.COINS_PER_BASKET)
		notifyAll(string.format("🏀 %s سجّل %d نقاط!", scorer.DisplayName, points), idx == 1 and COLORS.Red or COLORS.Blue)
		refresh()
		ballState.Locked = true
		local other = Match.Slots[3 - idx]
		task.delay(1.2, function()
			ballState.Locked = false
			if isMatchLive() and other and other.Parent then
				giveBall(other)
			end
		end)
	elseif recentShooter and shot then
		notify(recentShooter, string.format("🏀 سلة! %d نقاط (تدريب)", shot.Points), COLORS.Green)
	end
end

-- كشف دخول الكرة في السلة (لازم تنزل من فوق الحلقة لتحتها داخل الدائرة)
RunService.Heartbeat:Connect(function()
	local pos = ball.Position
	local prev = ballState.PrevPos
	ballState.PrevPos = pos
	if ballState.Holder or ballState.Locked or not prev then
		return
	end
	for _, hoop in pairs(hoops) do
		local c = hoop.Center
		if prev.Y >= c.Y and pos.Y < c.Y then
			local t = (prev.Y - c.Y) / (prev.Y - pos.Y)
			local cross = prev:Lerp(pos, t)
			if Vector2.new(cross.X - c.X, cross.Z - c.Z).Magnitude < RIM_R - 0.25 then
				onBasket(hoop)
			end
		end
	end
end)

-- فحص دوري: إذا مات حامل الكرة أو طلع، أو طاحت الكرة من الماب
task.spawn(function()
	while true do
		local holder = ballState.Holder
		if holder then
			local char = holder.Parent and holder.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local weld = ball:FindFirstChild("HoldWeld")
			if not hrp or not hum or hum.Health <= 0 or not weld or weld.Part0 ~= hrp then
				local dropAt = ball.Position
				releaseBall()
				ball.CFrame = CFrame.new(dropAt.X, math.max(dropAt.Y, 3), dropAt.Z)
			end
		elseif not isMatchLive() then
			local p = ball.Position
			if p.Y < -20 or math.abs(p.X) > 150 or math.abs(p.Z) > 150 then
				resetBallCenter()
			end
		end
		task.wait(0.1)
	end
end)

local function finishMatch(winnerIdx, reason)
	local p1, p2 = Match.Slots[1], Match.Slots[2]
	local message
	if winnerIdx then
		local winner = Match.Slots[winnerIdx]
		local loser = Match.Slots[3 - winnerIdx]
		addCoins(winner, CONFIG.COINS_WIN)
		addCoins(loser, CONFIG.COINS_LOSS)
		local prof = winner and profiles[winner]
		if prof then
			prof.Wins += 1
			updateLeaderstats(winner)
		end
		message = string.format("🏆 الفائز: %s (%d - %d)%s", winner and winner.DisplayName or "؟",
			Match.Scores[1], Match.Scores[2], reason and ("\n" .. reason) or "")
		notify(winner, "🏆 فزت! +" .. CONFIG.COINS_WIN .. " 🪙", COLORS.Gold)
		notify(loser, "خسرت هالمرة، +" .. CONFIG.COINS_LOSS .. " 🪙 للمشاركة", COLORS.White)
	else
		addCoins(p1, CONFIG.COINS_DRAW)
		addCoins(p2, CONFIG.COINS_DRAW)
		message = string.format("🤝 تعادل! (%d - %d)", Match.Scores[1], Match.Scores[2])
	end
	notifyAll(message, COLORS.Gold)
	resetBallCenter()
	setState("Ended", message)
	task.wait(CONFIG.RESULTS_TIME)
	for _, plr in ipairs({ p1, p2 }) do
		if plr and plr.Parent then
			teleport(plr, LOBBY_CF * CFrame.new(0, 0, plr == p1 and -3 or 3))
		end
	end
	Match.Slots = {}
	Match.Scores = { 0, 0 }
	Match.TimeLeft = CONFIG.MATCH_TIME
	resetBallCenter()
end

local function runMatch()
	local p1, p2 = Match.Slots[1], Match.Slots[2]
	Match.Scores = { 0, 0 }
	ballState.NoPickup = {}
	teleport(p1, SLOT_SPAWN[1])
	teleport(p2, SLOT_SPAWN[2])
	resetBallCenter()
	setState("Playing")
	notifyAll(string.format("🏀 بدأت المباراة: %s ضد %s!", p1.DisplayName, p2.DisplayName), COLORS.Gold)

	local endTime = os.clock() + CONFIG.MATCH_TIME
	while true do
		-- انسحاب أحد اللاعبين
		local p1Here, p2Here = p1.Parent ~= nil, p2.Parent ~= nil
		if not p1Here or not p2Here then
			finishMatch(p1Here and 1 or (p2Here and 2 or nil), "انسحب الخصم")
			return
		end

		local left = endTime - os.clock()
		Match.TimeLeft = math.max(0, math.ceil(left))

		if Match.State == "Overtime" and Match.Scores[1] ~= Match.Scores[2] then
			break
		end
		if left <= 0 then
			if Match.Scores[1] ~= Match.Scores[2] or Match.State == "Overtime" then
				break
			end
			setState("Overtime", "تعادل! أول سلة تفوز")
			notifyAll("⚡ تعادل! السلة الذهبية: أول من يسجّل يفوز", COLORS.Gold)
			endTime = os.clock() + CONFIG.OVERTIME_TIME
		end

		checkLiveBall()
		kickSpectatorsOffCourt()
		refresh()
		task.wait(0.1)
	end

	local winner = nil
	if Match.Scores[1] > Match.Scores[2] then
		winner = 1
	elseif Match.Scores[2] > Match.Scores[1] then
		winner = 2
	end
	finishMatch(winner)
end

-- الحلقة الرئيسية للعبة
task.spawn(function()
	while true do
		Match.TimeLeft = CONFIG.MATCH_TIME
		setState("Waiting")
		while not (Match.Slots[1] and Match.Slots[2]) do
			validateSlots()
			task.wait(0.25)
		end

		setState("Countdown")
		local ready = true
		for i = CONFIG.COUNTDOWN, 1, -1 do
			Match.TimeLeft = i
			refresh()
			for _ = 1, 4 do
				task.wait(0.25)
				validateSlots()
				if not (Match.Slots[1] and Match.Slots[2]) then
					ready = false
					break
				end
			end
			if not ready then
				break
			end
		end

		if ready then
			Match.TimeLeft = CONFIG.MATCH_TIME
			runMatch()
		else
			notifyAll("أُلغي العد التنازلي، أحد اللاعبين نزل من المربع", COLORS.Red)
		end
	end
end)

------------------------------------------------------------------
-- 🛒 الشراء والتجهيز
------------------------------------------------------------------
GetDataFn.OnServerInvoke = function(plr)
	local prof = waitForProfile(plr)
	if not prof then
		return nil
	end
	return { Profile = prof, Shop = SHOP }
end

local function equip(plr, category, id)
	local prof = profiles[plr]
	if category == "Balls" then
		prof.EquippedBall = id
		if ballState.Holder == plr then
			applyBallSkin(ball, id)
		end
	else
		prof.EquippedJersey = id
		applyJersey(plr)
	end
end

BuyFn.OnServerInvoke = function(plr, category, id)
	local prof = profiles[plr]
	local item = findItem(category, id)
	if not prof or not item then
		return { Success = false, Message = "غرض غير موجود" }
	end
	if prof[category][id] then
		return { Success = false, Message = "تملكه من قبل!", Profile = prof }
	end
	if prof.Coins < item.Price then
		return { Success = false, Message = "ما عندك عملات كافية 🪙", Profile = prof }
	end
	prof.Coins -= item.Price
	prof[category][id] = true
	equip(plr, category, id)
	updateLeaderstats(plr)
	return { Success = true, Message = "✅ اشتريت " .. item.Name .. " وتم تجهيزه!", Profile = prof }
end

EquipFn.OnServerInvoke = function(plr, category, id)
	local prof = profiles[plr]
	local item = findItem(category, id)
	if not prof or not item or not prof[category][id] then
		return { Success = false, Message = "لازم تشتريه أول" }
	end
	equip(plr, category, id)
	return { Success = true, Message = "تم تجهيز " .. item.Name, Profile = prof }
end

------------------------------------------------------------------
-- 👤 دخول وخروج اللاعبين
------------------------------------------------------------------
local function onPlayerAdded(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "عملات"
	coins.Parent = ls
	local wins = Instance.new("IntValue")
	wins.Name = "فوز"
	wins.Parent = ls
	ls.Parent = plr

	plr.CharacterAppearanceLoaded:Connect(function()
		applyJersey(plr)
	end)
	plr.CharacterAdded:Connect(function(char)
		local idx = slotIndex(plr)
		if idx and isMatchLive() then
			task.wait(0.2)
			if char.Parent then
				char:PivotTo(SLOT_SPAWN[idx])
			end
		end
	end)

	loadProfile(plr)
	if plr.Character then
		applyJersey(plr)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, plr)
end

Players.PlayerRemoving:Connect(function(plr)
	if ballState.Holder == plr then
		releaseBall()
	end
	if Match.State == "Waiting" or Match.State == "Countdown" then
		for i = 1, 2 do
			if Match.Slots[i] == plr then
				Match.Slots[i] = nil
			end
		end
	end
	ballState.NoPickup[plr] = nil
	ballState.StealCooldown[plr] = nil
	saveProfile(plr)
	profiles[plr] = nil
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		saveProfile(plr)
	end
end)

-- حفظ تلقائي كل دقيقتين
task.spawn(function()
	while true do
		task.wait(120)
		for _, plr in ipairs(Players:GetPlayers()) do
			saveProfile(plr)
		end
	end
end)

refresh()
print("🏀 تم بناء ملعب كرة السلة والمتجر بنجاح!")
