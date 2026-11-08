--==================================================================
-- 🏀 سكربت اللاعب: لوحة النتيجة + عداد الرمي + المتجر
-- المكان: StarterPlayer > StarterPlayerScripts  (نوعه LocalScript)
--
-- التحكم:
--   • كمبيوتر: اضغط مطولاً على زر الماوس الأيسر ثم أفلت للرمي، Q للتمرير، F للسرقة
--   • جوال: أزرار "رمي" و "تمرير" و "سرقة" على الشاشة
--   • يد تحكم: R2 للرمي، Y للتمرير، X للسرقة
--==================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Basketball")
local ShootEvent = remotes:WaitForChild("Shoot")
local StealEvent = remotes:WaitForChild("Steal")
local PassEvent = remotes:WaitForChild("Pass")
local NotifyEvent = remotes:WaitForChild("Notify")
local OpenShopEvent = remotes:WaitForChild("OpenShop")
local GetDataFn = remotes:WaitForChild("GetData")
local BuyFn = remotes:WaitForChild("Buy")
local EquipFn = remotes:WaitForChild("Equip")
local ball = workspace:WaitForChild("GameBall")

local PERFECT = remotes:GetAttribute("PerfectPower") or 0.85
local WINDOW = remotes:GetAttribute("PerfectWindow") or 0.06

local RED = Color3.fromRGB(230, 60, 60)
local BLUE = Color3.fromRGB(60, 130, 240)
local GOLD = Color3.fromRGB(240, 195, 60)
local GREEN = Color3.fromRGB(70, 200, 90)
local DARK = Color3.fromRGB(18, 18, 28)
local WHITE = Color3.new(1, 1, 1)

------------------------------------------------------------------
-- 🔊 أصوات الواجهة (تقدر تبدلها بـ "rbxassetid://الرقم" من Creator Store)
------------------------------------------------------------------
local UI_SOUNDS = {
	Beep = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1 },   -- العد التنازلي
	Buzzer = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 0.45 }, -- بداية ونهاية المباراة
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 1.6 },  -- شراء ناجح
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Speed = 1 },            -- أزرار المتجر
}

local soundObjects = {}
for name, def in pairs(UI_SOUNDS) do
	if def.Id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "BasketballUI_" .. name
		s.SoundId = def.Id
		s.Volume = def.Volume
		s.PlaybackSpeed = def.Speed
		s.Parent = SoundService
		soundObjects[name] = s
	end
end

local function playUi(name)
	local s = soundObjects[name]
	if s then
		s:Play()
	end
end

------------------------------------------------------------------
-- أدوات بناء الواجهة
------------------------------------------------------------------
local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(color, thickness)
	return make("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props, children)
	local defaults = { BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack,
		TextColor3 = WHITE, Text = "" }
	for k, v in pairs(defaults) do
		if props[k] == nil then
			props[k] = v
		end
	end
	return make("TextLabel", props, children)
end

local gui = make("ScreenGui", { Name = "BasketballUI", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

------------------------------------------------------------------
-- 📊 لوحة النتيجة أعلى الشاشة
------------------------------------------------------------------
local top = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(440, 66), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Parent = gui },
	{ corner(12), stroke(GOLD, 2) })

local p1NameL = label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(140, 20), TextColor3 = RED, Parent = top })
local p1ScoreL = label({ Position = UDim2.fromOffset(10, 24), Size = UDim2.fromOffset(140, 38), TextColor3 = RED, Parent = top })
local p2NameL = label({ Position = UDim2.new(1, -150, 0, 4), Size = UDim2.fromOffset(140, 20), TextColor3 = BLUE, Parent = top })
local p2ScoreL = label({ Position = UDim2.new(1, -150, 0, 24), Size = UDim2.fromOffset(140, 38), TextColor3 = BLUE, Parent = top })
local timeL = label({ Position = UDim2.new(0.5, -65, 0, 4), Size = UDim2.fromOffset(130, 34), TextColor3 = GOLD, Parent = top })
local stateL = label({ Position = UDim2.new(0.5, -65, 0, 40), Size = UDim2.fromOffset(130, 20), Font = Enum.Font.GothamBold, Parent = top })

-- رسالة كبيرة بالنص (العد التنازلي ونتيجة المباراة)
local banner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35),
	Size = UDim2.fromOffset(620, 90), TextColor3 = GOLD, TextStrokeTransparency = 0.2, Visible = false, Parent = gui })

-- العملات (أسفل اليسار)
local coinsFrame = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.fromOffset(130, 40), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Parent = gui },
	{ corner(10), stroke(GOLD, 2) })
local coinsL = label({ Size = UDim2.fromScale(1, 1), TextColor3 = GOLD, Text = "🪙 0", Parent = coinsFrame },
	{ make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

------------------------------------------------------------------
-- 🔔 الإشعارات
------------------------------------------------------------------
local toastHolder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82),
	Size = UDim2.fromOffset(480, 220), BackgroundTransparency = 1, Parent = gui },
	{ make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }) })
local toastCount = 0

local function toast(text, color)
	toastCount += 1
	local labels = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	if #labels >= 5 then
		labels[1]:Destroy()
	end
	local l = make("TextLabel", { LayoutOrder = toastCount, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2, Text = text, TextColor3 = color or WHITE, Font = Enum.Font.GothamBold,
		TextScaled = true, Parent = toastHolder },
		{ corner(8), make("UITextSizeConstraint", { MaxTextSize = 20 }),
			make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
	task.delay(3.2, function()
		if l.Parent then
			local tween = TweenService:Create(l, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			l:Destroy()
		end
	end)
end

NotifyEvent.OnClientEvent:Connect(function(text, color)
	toast(text, color)
end)

------------------------------------------------------------------
-- 🔄 تحديث لوحة النتيجة
------------------------------------------------------------------
local STATE_TEXT = {
	Waiting = "بانتظار لاعبين",
	Countdown = "استعداد...",
	Playing = "المباراة جارية",
	Overtime = "⚡ السلة الذهبية",
	Ended = "انتهت المباراة",
}

local lastState, lastTime = nil, nil

local function updateHud()
	local state = remotes:GetAttribute("State") or "Waiting"
	local t = remotes:GetAttribute("TimeLeft") or 0

	-- أصوات العد التنازلي والصافرة
	if state == "Countdown" and (t ~= lastTime or lastState ~= "Countdown") then
		playUi("Beep")
	end
	if state ~= lastState and (state == "Playing" or state == "Overtime" or state == "Ended") then
		playUi("Buzzer")
	end
	lastState, lastTime = state, t

	p1NameL.Text = remotes:GetAttribute("P1Name") or "—"
	p2NameL.Text = remotes:GetAttribute("P2Name") or "—"
	p1ScoreL.Text = tostring(remotes:GetAttribute("Score1") or 0)
	p2ScoreL.Text = tostring(remotes:GetAttribute("Score2") or 0)
	timeL.Text = string.format("%d:%02d", t // 60, t % 60)
	timeL.TextColor3 = (state == "Playing" and t <= 10) and RED or GOLD
	local mode = remotes:GetAttribute("Mode") or ""
	stateL.Text = (state == "Waiting" or mode == "") and (STATE_TEXT[state] or "") or ((STATE_TEXT[state] or "") .. " • " .. mode)

	if state == "Countdown" then
		banner.Text = tostring(t)
		banner.Visible = true
	elseif state == "Ended" then
		banner.Text = remotes:GetAttribute("Message") or ""
		banner.Visible = true
	else
		banner.Visible = false
	end
end

remotes.AttributeChanged:Connect(updateHud)
updateHud()

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("عملات")
	local function update()
		coinsL.Text = "🪙 " .. coins.Value
	end
	coins.Changed:Connect(update)
	update()
end)

------------------------------------------------------------------
-- 🎯 عداد قوة الرمي
------------------------------------------------------------------
local powerFrame = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(320, 28), BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false,
	Parent = gui }, { corner(8), stroke(WHITE, 2) })
make("Frame", { Position = UDim2.fromScale(PERFECT - WINDOW, 0), Size = UDim2.fromScale(WINDOW * 2, 1),
	BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 1, Parent = powerFrame })
local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, BackgroundTransparency = 0.45,
	BorderSizePixel = 0, ZIndex = 2, Parent = powerFrame })
local marker = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 4, 1, 0),
	BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = powerFrame })
local powerHint = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4),
	Size = UDim2.fromOffset(420, 22), Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.4, Parent = powerFrame })

local charging = false
local chargeStart = 0
local shootTouch = nil

local function isHolding()
	return ball:GetAttribute("HolderId") == player.UserId
end

-- القوة تطلع وتنزل بين 0 و 1 طول ما أنت ضاغط
local function currentPower()
	local t = (os.clock() - chargeStart) % 1.8
	local p = t / 0.9
	if p > 1 then
		p = 2 - p
	end
	return p
end

local function beginCharge()
	if isHolding() and not charging then
		charging = true
		chargeStart = os.clock()
	end
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	if isHolding() then
		ShootEvent:FireServer(currentPower())
	end
end

RunService.RenderStepped:Connect(function()
	local holding = isHolding()
	powerFrame.Visible = holding
	if not holding then
		charging = false
		return
	end
	local p = charging and currentPower() or 0
	fill.Size = UDim2.fromScale(p, 1)
	marker.Position = UDim2.fromScale(p, 0)

	local hint = charging and "أفلت في المنطقة الخضراء! 🎯" or "اضغط مطوّلاً للرمي  •  Q تمرير"
	local deadline = ball:GetAttribute("ShotDeadline") or 0
	if deadline > 0 then
		local remaining = math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
		hint = hint .. "   ⏱️ " .. remaining
	end
	powerHint.Text = hint
end)

------------------------------------------------------------------
-- 🎮 التحكم
------------------------------------------------------------------
local function isShootInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if isShootInput(input) then
		beginCharge()
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		StealEvent:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
		if isHolding() then
			charging = false
			PassEvent:FireServer()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == shootTouch then
		shootTouch = nil
		releaseCharge()
	elseif isShootInput(input) then
		releaseCharge()
	end
end)

-- أزرار الجوال
if UserInputService.TouchEnabled then
	local shootBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -170),
		Size = UDim2.fromOffset(90, 90), BackgroundColor3 = Color3.fromRGB(230, 110, 30), Text = "🏀\nرمي",
		TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextScaled = true, AutoButtonColor = true, Parent = gui },
		{ make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(WHITE, 3) })
	local stealBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -130, 1, -150),
		Size = UDim2.fromOffset(70, 70), BackgroundColor3 = Color3.fromRGB(70, 70, 90), Text = "🥷\nسرقة",
		TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextScaled = true, Parent = gui },
		{ make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(WHITE, 2) })

	local passBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -270),
		Size = UDim2.fromOffset(70, 70), BackgroundColor3 = Color3.fromRGB(40, 140, 90), Text = "🤝\nتمرير",
		TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextScaled = true, Parent = gui },
		{ make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(WHITE, 2) })
	passBtn.Activated:Connect(function()
		if isHolding() then
			charging = false
			PassEvent:FireServer()
		end
	end)

	shootBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			shootTouch = input
			beginCharge()
		end
	end)
	stealBtn.Activated:Connect(function()
		StealEvent:FireServer()
	end)
end

------------------------------------------------------------------
-- 🛒 واجهة المتجر
------------------------------------------------------------------
local shop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.85), BackgroundColor3 = DARK, Visible = false, ZIndex = 10, Parent = gui },
	{ corner(16), stroke(GOLD, 3), make("UISizeConstraint", { MaxSize = Vector2.new(620, 440) }) })

label({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -120, 0, 36), Text = "🛒 متجر السلة",
	TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11, Parent = shop })
local shopCoinsL = label({ Position = UDim2.fromOffset(60, 14), Size = UDim2.fromOffset(140, 28), TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = shop })
local closeBtn = make("TextButton", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = RED, Text = "✕", TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextScaled = true,
	ZIndex = 11, Parent = shop }, { corner(8) })

local tabs = {}
local function makeTab(name, text, x)
	tabs[name] = make("TextButton", { Position = UDim2.new(x, 8, 0, 56), Size = UDim2.new(0.5, -16, 0, 34),
		BackgroundColor3 = Color3.fromRGB(50, 50, 70), Text = text, TextColor3 = WHITE, Font = Enum.Font.GothamBold,
		TextScaled = true, ZIndex = 11, Parent = shop }, { corner(8),
		make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
end
makeTab("Jerseys", "👕 القمصان", 0)
makeTab("Balls", "🏀 الكرات", 0.5)

local list = make("ScrollingFrame", { Position = UDim2.fromOffset(12, 100), Size = UDim2.new(1, -24, 1, -112),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11, Parent = shop },
	{ make("UIGridLayout", { CellSize = UDim2.fromOffset(180, 190), CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })

local currentTab = "Balls"
local shopData = nil
local busy = false
local render -- (معرّفة تحت)

local EFFECT_ICON = { fire = "🔥", sparkles = "✨" }

local function onItemClicked(item, owned)
	if busy then
		return
	end
	busy = true
	playUi("Click")
	local ok, res = pcall(function()
		if owned then
			return EquipFn:InvokeServer(currentTab, item.Id)
		end
		return BuyFn:InvokeServer(currentTab, item.Id)
	end)
	busy = false
	if ok and type(res) == "table" then
		toast(res.Message or "", res.Success and GREEN or RED)
		if res.Success and not owned then
			playUi("Buy")
		end
		if res.Profile then
			shopData.Profile = res.Profile
		end
		render()
	else
		toast("صار خطأ، حاول مرة ثانية", RED)
	end
end

render = function()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not shopData then
		return
	end
	local profile = shopData.Profile
	shopCoinsL.Text = "🪙 " .. profile.Coins
	for name, tab in pairs(tabs) do
		tab.BackgroundColor3 = (name == currentTab) and GOLD or Color3.fromRGB(50, 50, 70)
		tab.TextColor3 = (name == currentTab) and DARK or WHITE
	end

	local equippedId = (currentTab == "Balls") and profile.EquippedBall or profile.EquippedJersey
	for i, item in ipairs(shopData.Shop[currentTab]) do
		local owned = profile[currentTab][item.Id] == true
		local equipped = equippedId == item.Id

		local card = make("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(35, 35, 50), ZIndex = 11,
			Parent = list }, { corner(12), stroke(equipped and GREEN or Color3.fromRGB(70, 70, 90), 2) })

		-- معاينة الغرض
		if currentTab == "Balls" then
			local preview = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(70, 70), BackgroundColor3 = item.Color, ZIndex = 12, Parent = card },
				{ make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(Color3.new(0, 0, 0), 2) })
			label({ Size = UDim2.fromScale(1, 1), Text = EFFECT_ICON[item.Effect] or "", ZIndex = 13, Parent = preview })
		else
			local preview = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(62, 70), BackgroundColor3 = item.Color or Color3.fromRGB(90, 90, 100),
				ZIndex = 12, Parent = card }, { corner(6), stroke(Color3.new(0, 0, 0), 2) })
			label({ Size = UDim2.fromScale(1, 1), Text = item.Number or "👤", TextColor3 = item.TextColor or WHITE,
				ZIndex = 13, Parent = preview }, { make("UIPadding", { PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		end

		label({ Position = UDim2.new(0, 6, 0, 90), Size = UDim2.new(1, -12, 0, 24), Text = item.Name,
			Font = Enum.Font.GothamBold, ZIndex = 12, Parent = card })
		label({ Position = UDim2.new(0, 6, 0, 116), Size = UDim2.new(1, -12, 0, 20),
			Text = item.Price == 0 and "مجاني" or (item.Price .. " 🪙"), TextColor3 = GOLD,
			Font = Enum.Font.GothamBold, ZIndex = 12, Parent = card })

		local btnText, btnColor
		if equipped then
			btnText, btnColor = "✔ مُجهّز", Color3.fromRGB(60, 120, 70)
		elseif owned then
			btnText, btnColor = "تجهيز", BLUE
		else
			local canAfford = profile.Coins >= item.Price
			btnText, btnColor = "شراء", canAfford and GREEN or Color3.fromRGB(110, 60, 60)
		end
		local btn = make("TextButton", { Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34),
			BackgroundColor3 = btnColor, Text = btnText, TextColor3 = WHITE, Font = Enum.Font.GothamBlack,
			TextScaled = true, AutoButtonColor = not equipped, ZIndex = 12, Parent = card },
			{ corner(8), make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
		if not equipped then
			btn.Activated:Connect(function()
				onItemClicked(item, owned)
			end)
		end
	end
end

for name, tab in pairs(tabs) do
	tab.Activated:Connect(function()
		currentTab = name
		playUi("Click")
		render()
	end)
end

closeBtn.Activated:Connect(function()
	shop.Visible = false
end)

OpenShopEvent.OnClientEvent:Connect(function()
	local ok, res = pcall(function()
		return GetDataFn:InvokeServer()
	end)
	if not ok or type(res) ~= "table" then
		toast("تعذّر فتح المتجر، حاول مرة ثانية", RED)
		return
	end
	shopData = res
	shop.Visible = true
	render()
end)
