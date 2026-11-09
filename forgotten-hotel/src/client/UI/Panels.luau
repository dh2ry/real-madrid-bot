--!nonstrict
-- Modal panels: document reader, keypad, elevator panel, final choice, inventory and the
-- ending screen. Opening a panel frees the mouse (Modal) and blocks gameplay input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Documents = require(Shared.Documents)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Progression = require(Shared.Progression)
local Config = require(Shared.Config)

local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local C, F = Theme.Colors, Theme.Fonts

local Panels = {}
local player = Players.LocalPlayer
local gui: ScreenGui
local current: Frame? = nil
local keypadInput: RBXScriptConnection? = nil

function Panels.Close()
	if current then
		current:Destroy()
		current = nil
	end
	if keypadInput then
		keypadInput:Disconnect()
		keypadInput = nil
	end
	State.Set("PanelOpen", nil)
end

local function open(name: string, dims: UDim2, maxSize: Vector2)
	Panels.Close()
	local backdrop = Theme.New("Frame", {
		Name = name,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	-- invisible modal button frees the mouse in first person
	Theme.New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Modal = true, Parent = backdrop })
	local panel = Theme.Panel(backdrop, { dims = dims, maxSize = maxSize, z = 2 })
	panel.Size = UDim2.new(dims.X.Scale * 0.92, dims.X.Offset, dims.Y.Scale * 0.92, dims.Y.Offset)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = dims }):Play()
	current = backdrop
	State.Set("PanelOpen", name)
	local close = Theme.Button(panel, "✕", Panels.Close, {
		dims = UDim2.fromOffset(34, 34),
		pos = UDim2.new(1, -8, 0, 8),
		anchor = Vector2.new(1, 0),
		font = F.ui,
		z = 5,
	})
	close.ZIndex = 5
	return panel
end

----------------------------------------------------------------------------------------
-- Document reader
----------------------------------------------------------------------------------------

function Panels.Document(docId: string)
	local doc = Documents[docId]
	if not doc then
		return
	end
	local panel = open("Document", UDim2.fromScale(0.5, 0.78), Vector2.new(620, 760))
	local paper = Theme.New("Frame", {
		BackgroundColor3 = C.paper,
		Position = UDim2.fromOffset(18, 52),
		Size = UDim2.new(1, -36, 1, -70),
		ZIndex = 3,
		Parent = panel,
	})
	Theme.Corner(paper, 4)
	Theme.Gradient(paper, C.paper, Color3.fromRGB(196, 180, 146), 120)
	Theme.Label(panel, (doc.journal and "مذكرات  ·  " or "وثيقة  ·  ") .. doc.where, { dims = UDim2.new(1, -80, 0, 18), pos = UDim2.fromOffset(18, 18), font = F.bold, color = C.gold, max = 13, z = 3 })
	local scroll = Theme.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 1, -24),
		Position = UDim2.fromOffset(16, 12),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.ink,
		ZIndex = 4,
		Parent = paper,
	})
	Theme.List(scroll, 10)
	local title = Theme.Label(scroll, doc.title, { dims = UDim2.new(1, -8, 0, 34), font = F.type, color = C.ink, max = 28, order = 1, z = 4 })
	title.TextScaled = true
	local body = Theme.Label(scroll, doc.body, { dims = UDim2.new(1, -8, 0, 0), font = F.type, color = C.ink, scaled = false, size = 19, order = 2, z = 4, valign = Enum.TextYAlignment.Top })
	body.AutomaticSize = Enum.AutomaticSize.Y
	Sounds.Play("Paper")
end

----------------------------------------------------------------------------------------
-- Keypad
----------------------------------------------------------------------------------------

function Panels.Keypad(id: string, title: string, digits: number)
	local panel = open("Keypad", UDim2.fromOffset(300, 430), Vector2.new(300, 430))
	Theme.Label(panel, title, { dims = UDim2.new(1, -60, 0, 24), pos = UDim2.fromOffset(16, 14), font = F.bold, color = C.gold, max = 16, z = 3 })
	local display = Theme.New("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(16, 4, 4),
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 0, 54),
		Font = Enum.Font.Arcade,
		TextColor3 = Color3.fromRGB(255, 90, 60),
		TextScaled = true,
		Text = string.rep("_ ", digits),
		ZIndex = 3,
		Parent = panel,
	})
	Theme.Corner(display, 4)
	local code = ""
	local function refresh()
		local shown = code .. string.rep("_", digits - #code)
		display.Text = shown:gsub(".", "%0 ")
	end
	local function press(key: string)
		if key == "C" then
			code = ""
		elseif key == "OK" then
			if #code == digits then
				Net.Event("Keypad"):FireServer(id, code)
				task.delay(0.15, Panels.Close)
			end
			return
		elseif #code < digits then
			code ..= key
		end
		Sounds.Play("Click")
		refresh()
	end
	local grid = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 120), Size = UDim2.new(1, -40, 1, -136), ZIndex = 3, Parent = panel })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -8, 0.25, -8)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, key in { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK" } do
		local b = Theme.Button(grid, key, function()
			press(key)
		end, { order = i, font = Enum.Font.Arcade, z = 4, color = key == "OK" and C.burgundy or nil })
		b.ZIndex = 4
	end
	keypadInput = UserInputService.InputBegan:Connect(function(input)
		local name = input.KeyCode.Name
		local map = { Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9" }
		local digit = map[name] or map[(name:gsub("KeypadZero", "Zero"):gsub("^Keypad", ""))]
		if digit then
			press(digit)
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			press("OK")
		elseif input.KeyCode == Enum.KeyCode.Backspace then
			code = code:sub(1, -2)
			refresh()
		end
	end)
end

----------------------------------------------------------------------------------------
-- Choices: elevator panel / final choice
----------------------------------------------------------------------------------------

function Panels.Elevator(data)
	local panel = open("Elevator", UDim2.fromOffset(280, 380), Vector2.new(280, 380))
	Theme.Label(panel, "اختر الطابق", { dims = UDim2.new(1, -60, 0, 24), pos = UDim2.fromOffset(16, 14), font = F.bold, color = C.gold, max = 16, z = 3 })
	local list = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 1, -70), ZIndex = 3, Parent = panel })
	Theme.List(list, 8)
	for i = #data.floors, 1, -1 do
		local floor = data.floors[i]
		local isCurrent = floor == data.current
		local b = Theme.Button(list, string.format("%s   ·   %s", data.labels[floor], data.names[floor]), function()
			Net.Event("Choice"):FireServer("elevator", floor)
			Panels.Close()
		end, { dims = UDim2.new(1, 0, 0, 60), order = #data.floors - i, z = 4, color = isCurrent and C.burgundy or nil })
		b.ZIndex = 4
	end
end

function Panels.FinalChoice(data)
	local panel = open("FinalChoice", UDim2.fromScale(0.6, 0.7), Vector2.new(760, 620))
	Theme.Label(panel, "القلب", { dims = UDim2.new(1, 0, 0, 44), pos = UDim2.fromOffset(0, 16), font = F.title, color = C.danger, align = Enum.TextXAlignment.Center, max = 40, z = 3 })
	Theme.Label(panel, "الفندق كله يُصغي. اختر.", { dims = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 60), font = F.body, color = C.dim, align = Enum.TextXAlignment.Center, max = 18, z = 3 })
	local list = Theme.New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 96), Size = UDim2.new(1, -48, 1, -112), ZIndex = 3, Parent = panel })
	Theme.List(list, 10)
	for i, option in data.options do
		local card = Theme.Button(list, "", function()
			if option.disabled then
				return
			end
			Net.Event("Choice"):FireServer("final", option.id)
			Panels.Close()
		end, { dims = UDim2.new(1, 0, 0.22, -6), order = i, z = 4, color = option.secret and Color3.fromRGB(30, 50, 46) or nil })
		card.ZIndex = 4
		Theme.Label(card, option.title, { dims = UDim2.new(1, -24, 0.45, 0), pos = UDim2.fromOffset(12, 6), font = F.title, color = option.secret and Color3.fromRGB(170, 255, 220) or C.gold, max = 26, z = 5 })
		Theme.Label(card, option.desc, { dims = UDim2.new(1, -24, 0.45, 0), pos = UDim2.new(0, 12, 0.5, 0), font = F.body, color = C.dim, max = 18, z = 5 })
		if option.disabled then
			Theme.SetDisabled(card, true)
		end
	end
end

----------------------------------------------------------------------------------------
-- Inventory
----------------------------------------------------------------------------------------

function Panels.Inventory()
	if current and current.Name == "Inventory" then
		Panels.Close()
		return
	end
	local panel = open("Inventory", UDim2.fromScale(0.5, 0.6), Vector2.new(640, 520))
	Theme.Label(panel, "الحقيبة", { dims = UDim2.new(1, -60, 0, 28), pos = UDim2.fromOffset(18, 14), font = F.title, color = C.gold, max = 26, z = 3 })
	local scroll = Theme.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 54),
		Size = UDim2.new(1, -36, 1, -70),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ZIndex = 3,
		Parent = panel,
	})
	Theme.List(scroll, 8)
	if #State.Inventory == 0 then
		Theme.Label(scroll, "جيوبك فارغة.", { dims = UDim2.new(1, 0, 0, 30), font = F.body, color = C.dim, max = 20, z = 3 })
	end
	for i, entry in State.Inventory do
		local def = Items[entry.id]
		if def then
			local row = Theme.New("Frame", { BackgroundColor3 = C.panel2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -8, 0, 64), LayoutOrder = i, ZIndex = 3, Parent = scroll })
			Theme.Corner(row, 6)
			Theme.Label(row, def.icon, { dims = UDim2.fromOffset(56, 64), font = F.ui, align = Enum.TextXAlignment.Center, max = 30, z = 4 })
			Theme.Label(row, def.name .. (entry.count > 1 and ("  x" .. entry.count) or ""), { dims = UDim2.new(1, -170, 0, 26), pos = UDim2.fromOffset(60, 6), font = F.title, color = C.gold, max = 20, z = 4 })
			Theme.Label(row, def.desc, { dims = UDim2.new(1, -170, 0, 26), pos = UDim2.fromOffset(60, 32), font = F.body, color = C.dim, max = 15, z = 4 })
			if entry.id == "Battery" or entry.id == "Bandage" then
				local use = Theme.Button(row, "استخدم", function()
					Net.Event("UseItem"):FireServer(entry.id)
					Panels.Close()
				end, { dims = UDim2.fromOffset(90, 40), pos = UDim2.new(1, -100, 0.5, 0), anchor = Vector2.new(0, 0.5), z = 5 })
				use.ZIndex = 5
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Ending
----------------------------------------------------------------------------------------

function Panels.Ending(endingId: string, results)
	Panels.Close()
	local ending = Progression.Endings[endingId]
	if not ending then
		return
	end
	local screen = Theme.New("Frame", { Name = "Ending", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui })
	Theme.New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Modal = true, ZIndex = 20, Parent = screen })
	current = screen
	State.Set("PanelOpen", "Ending")
	TweenService:Create(screen, TweenInfo.new(2.5), { BackgroundTransparency = 0 }):Play()
	task.wait(2.5)
	local column = Theme.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.8), ZIndex = 21, Parent = screen })
	Theme.New("UISizeConstraint", { MaxSize = Vector2.new(820, 700), Parent = column })
	local function line(text, font, color, height, y, size)
		local l = Theme.Label(column, text, { dims = UDim2.new(1, 0, 0, height), pos = UDim2.fromOffset(0, y), font = font, color = color, align = Enum.TextXAlignment.Center, max = size, z = 22 })
		l.TextTransparency = 1
		TweenService:Create(l, TweenInfo.new(1.5), { TextTransparency = 0 }):Play()
		return l
	end
	line(ending.subtitle, F.bold, C.gold, 20, 0, 16)
	task.wait(0.6)
	line(ending.title, F.title, C.text, 70, 28, 64)
	task.wait(0.8)
	local body = line(ending.text, F.body, C.dim, 180, 110, 22)
	body.TextYAlignment = Enum.TextYAlignment.Top
	task.wait(1)
	local minutes = math.floor(results.time / 60)
	line(string.format("الوقت  %d:%02d     ·     الوثائق  %d/12     ·     %s%s", minutes, results.time % 60, results.documents, (Config.Difficulty[results.difficulty] and Config.Difficulty[results.difficulty].label or results.difficulty), results.untouched and "     ·     دون إصابة" or ""), F.ui, C.text, 22, 310, 16)
	line(string.format("+ %d عملة", results.coins), F.title, C.gold, 34, 344, 28)
	local countdown = line("", F.body, C.dim, 22, 400, 16)
	task.spawn(function()
		for t = 24, 0, -1 do
			if not countdown.Parent then
				return
			end
			countdown.Text = string.format("الفندق سينساك خلال %d...", t)
			task.wait(1)
		end
	end)
end

----------------------------------------------------------------------------------------

function Panels.IsOpen(): boolean
	return current ~= nil
end

function Panels.Init()
	gui = Theme.New("ScreenGui", {
		Name = "HotelPanels",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Net.Event("Document").OnClientEvent:Connect(Panels.Document)
	Net.Event("Keypad").OnClientEvent:Connect(Panels.Keypad)
	Net.Event("Choice").OnClientEvent:Connect(function(context, data)
		if context == "elevator" then
			Panels.Elevator(data)
		elseif context == "final" then
			Panels.FinalChoice(data)
		end
	end)
	Net.Event("Ending").OnClientEvent:Connect(function(endingId, results)
		Panels.Ending(endingId, results)
	end)
	State.Changed:Connect(function(key, value)
		if key == "RunState" and value.state == "Lobby" and current and current.Name == "Ending" then
			Panels.Close()
		end
	end)
end

return Panels
