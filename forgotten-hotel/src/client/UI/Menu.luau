--!nonstrict
-- Main menu, multiplayer lobby, settings (graphics / audio / camera / controls) and extras
-- (achievements, flashlight skins, document archive, endings, stats). Doubles as the
-- pause menu during a run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Documents = require(Shared.Documents)
local MissionDefs = require(Shared.Missions)
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)

local State = require(script.Parent.Parent.State)
local Settings = require(script.Parent.Parent.Settings)
local Theme = require(script.Parent.Theme)
local Panels = require(script.Parent.Panels)
local C, F = Theme.Colors, Theme.Fonts

local Menu = {}
local player = Players.LocalPlayer
local gui: ScreenGui
local root: Frame
local sidePanel: Frame
local buttons = {}
local page: Frame? = nil
local coinsLabel: TextLabel

local function lobbyAction(action: string, arg: any?)
	Net.Event("Lobby"):FireServer(action, arg)
end

local function isHost(): boolean
	return State.RunState.host == player.UserId
end

local function clearPage()
	if page then
		page:Destroy()
		page = nil
	end
end

local function newPage(title: string): Frame
	clearPage()
	page = Theme.Panel(root, {
		name = "Page",
		dims = UDim2.new(0.56, 0, 0.74, 0),
		pos = UDim2.new(0.97, 0, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		maxSize = Vector2.new(760, 640),
		z = 3,
	})
	Theme.Label(page, title, { dims = UDim2.new(1, -40, 0, 34), pos = UDim2.fromOffset(20, 14), font = F.title, color = C.gold, max = 30, z = 4 })
	Theme.Button(page, "✕", clearPage, { dims = UDim2.fromOffset(34, 34), pos = UDim2.new(1, -10, 0, 10), anchor = Vector2.new(1, 0), font = F.ui, z = 5 }).ZIndex = 5
	return page
end

local function scrollArea(parent: Instance, top: number?)
	local scroll = Theme.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, top or 58),
		Size = UDim2.new(1, -40, 1, -(top or 58) - 16),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.gold,
		ZIndex = 4,
		Parent = parent,
	})
	Theme.List(scroll, 6)
	return scroll
end

local function tabs(parent: Frame, names: { string }, onSelect: (string) -> ())
	local bar = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 54), Size = UDim2.new(1, -40, 0, 34), ZIndex = 4, Parent = parent })
	Theme.List(bar, 6, true)
	local tabButtons = {}
	local function select(name)
		for n, b in tabButtons do
			b.BackgroundColor3 = n == name and C.burgundy or C.panel2
		end
		onSelect(name)
	end
	for i, name in names do
		local b = Theme.Button(bar, name, function()
			select(name)
		end, { dims = UDim2.new(1 / #names, -6, 1, 0), order = i, font = F.bold, max = 13, z = 5 })
		b.ZIndex = 5
		tabButtons[name] = b
	end
	select(names[1])
end

----------------------------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------------------------

local function settingRow(parent: Instance, order: number, label: string, getText: () -> string, onMinus: (() -> ())?, onPlus: (() -> ())?)
	local row = Theme.New("Frame", { BackgroundColor3 = C.panel2, BackgroundTransparency = 0.4, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = order, ZIndex = 4, Parent = parent })
	Theme.Corner(row, 6)
	Theme.Label(row, label, { dims = UDim2.new(0.5, -10, 1, 0), pos = UDim2.fromOffset(12, 0), font = F.body, max = 19, z = 5 })
	local value = Theme.Label(row, getText(), { dims = UDim2.new(0.25, 0, 1, 0), pos = UDim2.fromScale(0.58, 0), font = F.ui, color = C.gold, align = Enum.TextXAlignment.Center, max = 16, z = 5 })
	local function refresh()
		value.Text = getText()
	end
	if onMinus then
		Theme.Button(row, "−", function()
			onMinus()
			refresh()
		end, { dims = UDim2.fromOffset(36, 32), pos = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0, 0.5), font = F.ui, z = 6 }).ZIndex = 6
	end
	if onPlus then
		Theme.Button(row, "+", function()
			onPlus()
			refresh()
		end, { dims = UDim2.fromOffset(36, 32), pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5), font = F.ui, z = 6 }).ZIndex = 6
	end
	return row
end

local function numberSetting(parent, order, label, key, step, fmt)
	settingRow(parent, order, label, function()
		return string.format(fmt or "%.2f", State.Settings[key])
	end, function()
		Settings.Set(key, State.Settings[key] - step)
	end, function()
		Settings.Set(key, State.Settings[key] + step)
	end)
end

local function toggleSetting(parent, order, label, key)
	settingRow(parent, order, label, function()
		return State.Settings[key] and "تشغيل" or "إيقاف"
	end, nil, function()
		Settings.Set(key, not State.Settings[key])
	end)
end

local function showSettings()
	local p = newPage("الإعدادات")
	local content
	tabs(p, { "الرسوميات", "الصوت", "الكاميرا", "التحكم" }, function(tab)
		if content then
			content:Destroy()
		end
		content = scrollArea(p, 100)
		if tab == "الرسوميات" then
			toggleSetting(content, 1, "جزيئات الغبار", "particles")
			toggleSetting(content, 2, "المطر", "rain")
			toggleSetting(content, 3, "الظلال الديناميكية", "shadows")
			numberSetting(content, 4, "السطوع", "brightness", 0.05)
			Theme.Label(content, "نصيحة: على الهواتف الضعيفة أوقف الظلال والجزيئات. يضبط Roblox الجودة تلقائيًا أيضًا (Esc > الإعدادات > الرسوميات).", { dims = UDim2.new(1, -8, 0, 44), font = F.body, color = C.dim, max = 15, order = 9, z = 4 })
		elseif tab == "الصوت" then
			numberSetting(content, 1, "الصوت العام", "master", 0.1)
			numberSetting(content, 2, "الموسيقى", "music", 0.1)
			numberSetting(content, 3, "المؤثرات الصوتية", "sfx", 0.1)
			numberSetting(content, 4, "الأجواء", "ambience", 0.1)
		elseif tab == "الكاميرا" then
			settingRow(content, 1, "وضع الكاميرا", function()
				return State.Settings.cameraMode == "first" and "منظور الشخص الأول" or "منظور الشخص الثالث"
			end, nil, function()
				Settings.Set("cameraMode", State.Settings.cameraMode == "first" and "third" or "first")
			end)
			numberSetting(content, 2, "مجال الرؤية", "fov", 5, "%d")
			numberSetting(content, 3, "الحساسية", "sensitivity", 0.1)
			toggleSetting(content, 4, "اهتزاز الرأس", "headBob")
		else
			local lines = {
				"الحركة ........... WASD / العصا اليسرى / عصا اللمس",
				"تفاعل ........... E / زر X / المس الإشارة",
				"المصباح ......... F / زر Y / ضوء",
				"الركض (مطولًا) .. Shift / L3 / ركض (تبديل)",
				"التسلّل .......... C أو Ctrl / زر B / تسلّل",
				"تبديل البطارية .. R / السهم للأعلى / بطارية",
				"ضمادة ........... H / السهم للأسفل / علاج",
				"منظور الكاميرا .. V / السهم لليمين / منظور",
				"الحقيبة ......... Tab أو I / R1 / حقيبة",
				"القائمة ......... M أو P / Start / قائمة",
			}
			for i, text in lines do
				Theme.Label(content, text, { dims = UDim2.new(1, -8, 0, 26), font = Enum.Font.Code, color = C.text, max = 16, order = i, z = 4 })
			end
		end
	end)
end

----------------------------------------------------------------------------------------
-- Extras
----------------------------------------------------------------------------------------

local function showExtras()
	local p = newPage("الإضافات")
	local content
	tabs(p, { "الإنجازات", "المظاهر", "الأرشيف", "النهايات", "الإحصائيات" }, function(tab)
		if content then
			content:Destroy()
		end
		content = scrollArea(p, 100)
		local profile = State.Profile or { achievements = {}, skins = {}, docs = {}, endings = {}, stats = {}, coins = 0 }
		if tab == "الإنجازات" then
			for i, id in Progression.AchievementOrder do
				local def = Progression.Achievements[id]
				local got = profile.achievements[id] ~= nil
				local row = Theme.New("Frame", { BackgroundColor3 = got and C.deep or C.panel2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -8, 0, 50), LayoutOrder = i, ZIndex = 4, Parent = content })
				Theme.Corner(row, 6)
				Theme.Label(row, got and "🏆" or "🔒", { dims = UDim2.fromOffset(46, 50), font = F.ui, align = Enum.TextXAlignment.Center, max = 22, z = 5 })
				Theme.Label(row, def.name, { dims = UDim2.new(1, -60, 0, 24), pos = UDim2.fromOffset(50, 4), font = F.title, color = got and C.gold or C.dim, max = 19, z = 5 })
				Theme.Label(row, def.desc, { dims = UDim2.new(1, -60, 0, 18), pos = UDim2.fromOffset(50, 28), font = F.body, color = C.dim, max = 14, z = 5 })
			end
		elseif tab == "المظاهر" then
			for i, id in Progression.SkinOrder do
				local skin = Progression.Skins[id]
				local owned = profile.skins[id] == true
				local equipped = profile.skin == id
				local row = Theme.New("Frame", { BackgroundColor3 = C.panel2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -8, 0, 54), LayoutOrder = i, ZIndex = 4, Parent = content })
				Theme.Corner(row, 6)
				local swatch = Theme.New("Frame", { BackgroundColor3 = skin.beam, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(34, 34), ZIndex = 5, Parent = row })
				Theme.Corner(swatch, 17)
				Theme.Stroke(swatch, skin.body, 3, 0)
				Theme.Label(row, skin.name, { dims = UDim2.new(1, -200, 0, 24), pos = UDim2.fromOffset(54, 6), font = F.title, color = owned and C.text or C.dim, max = 19, z = 5 })
				local how = skin.unlock and ("يُفتح بـ: " .. Progression.Achievements[skin.unlock].name) or "افتراضي"
				Theme.Label(row, how, { dims = UDim2.new(1, -200, 0, 18), pos = UDim2.fromOffset(54, 30), font = F.body, color = C.dim, max = 14, z = 5 })
				local b = Theme.Button(row, equipped and "مُجهَّز" or (owned and "تجهيز" or "مقفل"), function()
					Net.Event("EquipSkin"):FireServer(id)
				end, { dims = UDim2.fromOffset(110, 36), pos = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), font = F.bold, max = 13, z = 6 })
				b.ZIndex = 6
				Theme.SetDisabled(b, not owned or equipped)
			end
		elseif tab == "الأرشيف" then
			for i, id in Documents.Order do
				local doc = Documents[id]
				local read = profile.docs[id] == true
				local b = Theme.Button(content, read and doc.title or "??? - " .. doc.where, function()
					if read then
						Menu.Close(true)
						Panels.Document(id)
					end
				end, { dims = UDim2.new(1, -8, 0, 40), order = i, font = F.body, align = Enum.TextXAlignment.Right, max = 17, z = 5 })
				b.ZIndex = 5
				Theme.SetDisabled(b, not read)
			end
		elseif tab == "النهايات" then
			local order = { "escape", "liberation", "concierge", "secret" }
			for i, id in order do
				local ending = Progression.Endings[id]
				local got = profile.endings[id] == true
				local row = Theme.New("Frame", { BackgroundColor3 = got and C.deep or C.panel2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -8, 0, 56), LayoutOrder = i, ZIndex = 4, Parent = content })
				Theme.Corner(row, 6)
				Theme.Label(row, got and ending.title or "? ? ?", { dims = UDim2.new(1, -20, 0, 26), pos = UDim2.fromOffset(12, 4), font = F.title, color = got and C.gold or C.dim, max = 21, z = 5 })
				Theme.Label(row, ending.subtitle, { dims = UDim2.new(1, -20, 0, 18), pos = UDim2.fromOffset(12, 32), font = F.body, color = C.dim, max = 14, z = 5 })
			end
		else
			local stats = profile.stats or {}
			local docCount = 0
			for _ in profile.docs do
				docCount += 1
			end
			for i, text in {
				"العملات: " .. tostring(profile.coins or 0),
				"جولات بدأت: " .. tostring(stats.runs or 0),
				"جولات منتهية: " .. tostring(stats.wins or 0),
				"مرات الهروب: " .. tostring(stats.escapes or 0),
				"مرات الموت: " .. tostring(stats.deaths or 0),
				string.format("الوثائق المقروءة: %d/%d", docCount, Config.TotalDocuments),
				profile.online == false and "الحفظ غير متاح (دون اتصال / Studio بلا وصول API)" or "يُحفظ التقدّم تلقائيًا",
			} do
				Theme.Label(content, text, { dims = UDim2.new(1, -8, 0, 30), font = F.body, color = i == 7 and C.dim or C.text, max = 19, order = i, z = 4 })
			end
		end
	end)
end

----------------------------------------------------------------------------------------
-- Lobby
----------------------------------------------------------------------------------------

local lobbyRefresh: (() -> ())? = nil

local function showLobby()
	local p = newPage("ردهة اللعب الجماعي")
	local list = scrollArea(p, 58)
	list.Size = UDim2.new(0.55, -20, 1, -74)
	local controls = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.55, 10, 0, 58), Size = UDim2.new(0.45, -30, 1, -74), ZIndex = 4, Parent = p })
	Theme.List(controls, 8)
	local diffLabel = Theme.Label(controls, "", { dims = UDim2.new(1, 0, 0, 22), font = F.bold, color = C.gold, max = 14, order = 1, z = 5 })
	local diffRow = Theme.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 2, ZIndex = 5, Parent = controls })
	Theme.List(diffRow, 4, true)
	local diffButtons = {}
	for i, id in Config.DifficultyOrder do
		local b = Theme.Button(diffRow, Config.Difficulty[id].label, function()
			lobbyAction("Difficulty", id)
		end, { dims = UDim2.new(1 / 3, -3, 1, 0), order = i, font = F.bold, max = 12, z = 6 })
		b.ZIndex = 6
		diffButtons[id] = b
	end
	local readyButton = Theme.Button(controls, "مستعد", function()
		lobbyAction("Ready")
	end, { order = 3, z = 5 })
	local startButton = Theme.Button(controls, "ابدأ الجولة", function()
		lobbyAction("Start")
	end, { order = 4, z = 5, color = C.burgundy })
	local continueButton = Theme.Button(controls, "متابعة الجولة المحفوظة", function()
		lobbyAction("Continue")
	end, { order = 5, z = 5 })
	Theme.Button(controls, "ادعُ أصدقاءك", function()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end, { order = 6, z = 5 })
	local privateButton = Theme.Button(controls, "جولة خاصة (للمستعدين)", function()
		lobbyAction("Private")
	end, { order = 7, z = 5, max = 16 })
	local note = Theme.Label(controls, "", { dims = UDim2.new(1, 0, 0, 40), font = F.body, color = C.dim, max = 14, order = 8, z = 5 })

	lobbyRefresh = function()
		if not list.Parent then
			lobbyRefresh = nil
			return
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local rs = State.RunState
		for i, entry in rs.players or {} do
			local row = Theme.New("Frame", { BackgroundColor3 = C.panel2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = i, ZIndex = 5, Parent = list })
			Theme.Corner(row, 6)
			local crown = entry.userId == rs.host and "👑 " or ""
			Theme.Label(row, crown .. entry.name, { dims = UDim2.new(0.65, 0, 1, 0), pos = UDim2.fromOffset(12, 0), font = F.body, max = 18, z = 6 })
			local status = entry.inRun and "في الجولة" or (entry.ready and "مستعد" or "...")
			Theme.Label(row, status, { dims = UDim2.new(0.3, 0, 1, 0), pos = UDim2.fromScale(0.68, 0), font = F.bold, color = entry.ready and C.good or C.dim, align = Enum.TextXAlignment.Right, max = 13, z = 6 })
		end
		local host = isHost()
		diffLabel.Text = "الصعوبة: " .. (Config.Difficulty[rs.difficulty or "Normal"] or Config.Difficulty.Normal).label .. (host and "" or "  (المضيف يقرّر)")
		for id, b in diffButtons do
			b.BackgroundColor3 = id == rs.difficulty and C.burgundy or C.panel2
			Theme.SetDisabled(b, not host or rs.state ~= "Lobby")
		end
		local me
		for _, entry in rs.players or {} do
			if entry.userId == player.UserId then
				me = entry
			end
		end
		readyButton.Label.Text = me and me.ready and "غير مستعد" or "مستعد"
		Theme.SetDisabled(readyButton, rs.state ~= "Lobby")
		Theme.SetDisabled(startButton, not host or rs.state ~= "Lobby")
		continueButton.Visible = host and rs.canContinue == true
		if rs.continueMission and MissionDefs[rs.continueMission] then
			continueButton.Label.Text = "متابعة: " .. MissionDefs[rs.continueMission].title
		end
		Theme.SetDisabled(privateButton, not host or rs.privateServer)
		if rs.state == "Playing" then
			note.Text = "هناك جولة جارية - اضغط «العب» للانضمام."
		elseif rs.privateServer then
			note.Text = "خادم خاص. لا ينضم إلا المدعوون."
		else
			note.Text = string.format("حتى %d لاعبين. تبدأ الجولة عندما يستعد الجميع أو يبدأها المضيف.", Config.MaxPlayers)
		end
	end
	lobbyRefresh()
end

----------------------------------------------------------------------------------------
-- Root menu
----------------------------------------------------------------------------------------

local function refreshButtons()
	local rs = State.RunState
	local inRun = State.InRun()
	local playText
	if inRun then
		playText = "استئناف"
	elseif rs.state == "Playing" then
		playText = "انضم للجولة"
	elseif rs.state == "Ending" then
		playText = "يرجى الانتظار..."
	else
		playText = #(rs.players or {}) > 1 and "العب  (استعد)" or "العب"
	end
	buttons.play.Label.Text = playText
	Theme.SetDisabled(buttons.play, rs.state == "Ending")
	buttons.lobby.Visible = not inRun
	if State.Profile then
		coinsLabel.Text = string.format("🪙  %d", State.Profile.coins or 0)
	end
	if lobbyRefresh then
		lobbyRefresh()
	end
end

function Menu.Open()
	root.Visible = true
	State.Set("MenuOpen", true)
	refreshButtons()
	root.BackgroundTransparency = 1
	TweenService:Create(root, TweenInfo.new(0.4), { BackgroundTransparency = State.InRun() and 0.35 or 0.55 }):Play()
end

function Menu.Close(keepPage: boolean?)
	if not keepPage then
		clearPage()
	end
	root.Visible = false
	State.Set("MenuOpen", false)
end

function Menu.Toggle()
	if root.Visible then
		if State.InRun() then
			Menu.Close()
		end
	else
		Panels.Close()
		Menu.Open()
	end
end

function Menu.Init()
	gui = Theme.New("ScreenGui", {
		Name = "HotelMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = Theme.New("Frame", { Name = "Root", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), Parent = gui })
	Theme.New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Modal = true, Parent = root })
	Theme.Vignette(root, Color3.new(0, 0, 0), 0.9, 1)
	sidePanel = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.34, 0.86), ZIndex = 2, Parent = root })
	Theme.New("UISizeConstraint", { MinSize = Vector2.new(240, 0), MaxSize = Vector2.new(460, 2000), Parent = sidePanel })
	local title = Theme.Label(sidePanel, "الفندق\nالمنسي", { dims = UDim2.new(1, 0, 0.22, 0), font = F.title, color = C.gold, max = 64, z = 3 })
	Theme.Stroke(title, Color3.new(0, 0, 0), 2, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	Theme.Label(sidePanel, "THE FORGOTTEN HOTEL", { dims = UDim2.new(1, 0, 0.06, 0), pos = UDim2.fromScale(0, 0.22), font = Enum.Font.Arial, color = C.text, max = 34, z = 3 })
	Theme.Label(sidePanel, "بعض الضيوف لا يغادرون أبدًا.", { dims = UDim2.new(1, 0, 0.04, 0), pos = UDim2.fromScale(0, 0.285), font = F.body, color = C.dim, max = 20, z = 3 })
	local column = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.37), Size = UDim2.new(1, 0, 0.5, 0), ZIndex = 3, Parent = sidePanel })
	local layout = Theme.List(column, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	local function menuButton(order: number, text: string, onClick)
		local b = Theme.Button(column, text, onClick, { dims = UDim2.new(0.86, 0, 0, 50), order = order, align = Enum.TextXAlignment.Right, max = 26, z = 4 })
		b.ZIndex = 4
		return b
	end
	buttons.play = menuButton(1, "العب", function()
		if State.InRun() then
			Menu.Close()
			return
		end
		lobbyAction("Play")
		if #(State.RunState.players or {}) > 1 and State.RunState.state == "Lobby" then
			showLobby()
		end
	end)
	buttons.lobby = menuButton(2, "ردهة اللعب الجماعي", showLobby)
	buttons.settings = menuButton(3, "الإعدادات", showSettings)
	buttons.extras = menuButton(4, "الإضافات", showExtras)
	coinsLabel = Theme.Label(sidePanel, "🪙  0", { dims = UDim2.new(1, 0, 0, 26), pos = UDim2.new(0, 0, 1, -30), font = F.ui, color = C.gold, max = 18, z = 3 })
	Theme.Label(root, "يُنصح باستخدام السماعات.  العب في الظلام.", { dims = UDim2.new(0.5, 0, 0, 20), pos = UDim2.new(0.5, 0, 1, -28), anchor = Vector2.new(0.5, 0), font = F.body, color = C.dim, align = Enum.TextXAlignment.Center, max = 15, z = 2 })

	State.Changed:Connect(function(key, value)
		if key == "RunState" then
			local inRun = State.InRun()
			-- when the run starts for us, close the menu; when we're back in the lobby, open it
			if value.state == "Playing" and inRun and root.Visible and not Menu._wasInRun then
				Menu.Close()
			elseif value.state == "Lobby" and not root.Visible then
				Menu.Open()
			end
			Menu._wasInRun = inRun
			refreshButtons()
		elseif key == "Profile" then
			refreshButtons()
		end
	end)
	Menu.Open()
end

return Menu
