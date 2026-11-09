--!nonstrict
-- Interactive puzzle objects: keypads/safes, breaker, library books, generator,
-- secret bookcase, loose wall panel. Puzzles only set story flags on Run; the Missions
-- service reacts to those flags.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local Build = require(script.Parent.Parent.Map.Build)
local Run = require(script.Parent.Run)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Power = require(script.Parent.Power)

local Puzzles = {}
Puzzles.Keypads = {} :: { [string]: any }

local C = Config.Palette
local M = Enum.Material

----------------------------------------------------------------------------------------
-- Keypads (also used for safes)
----------------------------------------------------------------------------------------

-- `cf` on the wall surface, facing out. opts: id, code, title, zone (power zone needed), onSolved
function Puzzles.Keypad(parent: Instance, cf: CFrame, opts)
	local m = Build.Model(parent, "Keypad_" .. opts.id)
	Build.D(m, Vector3.new(1.3, 1.9, 0.2), cf * CFrame.new(0, 0, -0.1), Color3.fromRGB(46, 46, 48), M.Metal)
	local screen = Build.D(m, Vector3.new(1, 0.35, 0.05), cf * CFrame.new(0, 0.6, -0.22), Color3.fromRGB(40, 10, 10), M.Neon, { name = "Screen" })
	for row = 0, 3 do
		for col = 0, 2 do
			Build.D(m, Vector3.new(0.24, 0.2, 0.08), cf * CFrame.new(-0.3 + col * 0.3, 0.15 - row * 0.27, -0.22), Color3.fromRGB(150, 150, 150), M.Metal)
		end
	end
	local keypad = { id = opts.id, code = opts.code, title = opts.title or "لوحة الأرقام", zone = opts.zone, solved = false, model = m, screen = screen, onSolved = opts.onSolved, cf = cf }
	Puzzles.Keypads[opts.id] = keypad
	local anchor = Interact.Anchor(m, (cf * CFrame.new(0, 0, -0.6)).Position, "Anchor")
	keypad.anchor = anchor
	keypad.prompt = Interact.Add(anchor, { text = "أدخل الرمز", object = keypad.title, dist = 6 }, function(player)
		if keypad.solved then
			Run.Notify(player, "إنه مفتوح بالفعل.", "info")
			return
		end
		if keypad.zone and not Power.IsOn(keypad.zone) then
			Run.Notify(player, "لوحة الأرقام ميتة. لا توجد كهرباء.", "warn")
			Sounds.Play("Locked", anchor)
			return
		end
		Net.Event("Keypad"):FireClient(player, keypad.id, keypad.title, #keypad.code)
	end)
	return keypad
end

function Puzzles.SolveKeypad(id: string, player: Player?)
	local keypad = Puzzles.Keypads[id]
	if not keypad or keypad.solved then
		return
	end
	keypad.solved = true
	keypad.screen.Color = Color3.fromRGB(40, 200, 90)
	keypad.prompt.Enabled = false
	Sounds.Play("Unlock", keypad.anchor)
	if keypad.onSolved then
		keypad.onSolved(player)
	end
end

----------------------------------------------------------------------------------------
-- Breaker panel (mission: restore electricity)
----------------------------------------------------------------------------------------

function Puzzles.Breaker(parent: Instance, cf: CFrame)
	local m = Build.Model(parent, "Breaker")
	Build.P(m, Vector3.new(4, 5, 1), cf * CFrame.new(0, 5, -0.5), Color3.fromRGB(70, 74, 72), M.Metal)
	Build.D(m, Vector3.new(3.4, 4.4, 0.1), cf * CFrame.new(0, 5, -1.02), Color3.fromRGB(40, 42, 40), M.Metal)
	for i = 0, 5 do
		Build.D(m, Vector3.new(0.4, 0.6, 0.15), cf * CFrame.new(-1.2 + (i % 3) * 0.6, 6.2 - math.floor(i / 3) * 0.9, -1.1), C.Bone, M.SmoothPlastic)
	end
	local slot = Build.D(m, Vector3.new(0.6, 1, 0.15), cf * CFrame.new(0.9, 4, -1.1), Color3.fromRGB(10, 10, 10), M.SmoothPlastic, { name = "FuseSlot" })
	local lever = Build.D(m, Vector3.new(0.3, 1.6, 0.3), cf * CFrame.new(2.4, 5.6, -0.8) * CFrame.Angles(math.rad(-40), 0, 0), C.Emergency, M.Metal, { name = "Lever" })
	Build.Text(m, Vector3.new(3, 0.5, 0.05), cf * CFrame.new(0, 7.8, -1.05), "القاطع الرئيسي", { bg = Color3.fromRGB(200, 170, 40), color = C.Black, font = Enum.Font.GothamBold })
	local fused = false
	local anchor = Interact.Anchor(m, (cf * CFrame.new(0.9, 4.6, -1.6)).Position, "Anchor")
	local prompt
	prompt = Interact.Add(anchor, { text = "افحص", object = "القاطع الرئيسي", dist = 7, hold = 0.4 }, function(player)
		if Run.Flag("power") then
			return
		end
		if not fused then
			if Inventory.Remove(player, "Fuse", 1) then
				fused = true
				Build.D(m, Vector3.new(0.4, 0.9, 0.2), slot.CFrame * CFrame.new(0, 0, -0.05), C.Bone, M.SmoothPlastic)
				Sounds.Play("Click", anchor)
				prompt.ActionText = "اسحب الذراع"
				prompt.HoldDuration = 1.2
				Run.Notify(player, "استقر الفيوز في مكانه. الآن الذراع.", "item")
			else
				Run.Notify(player, "الفيوز مفقود من مكانه.", "warn")
				Sounds.Play("Locked", anchor)
			end
			return
		end
		TweenService:Create(lever, TweenInfo.new(0.3), { CFrame = cf * CFrame.new(2.4, 5, -0.8) * CFrame.Angles(math.rad(40), 0, 0) }):Play()
		Sounds.Play("Lever", anchor)
		prompt.Enabled = false
		Run.SetFlag("power", true)
	end)
	return m
end

----------------------------------------------------------------------------------------
-- Library books (housekeeping rhyme: Red, Gold, Blue, Black)
----------------------------------------------------------------------------------------

function Puzzles.Books(parent: Instance, shelfCF: CFrame, onSolved: (Player) -> ())
	local m = Build.Model(parent, "BookPuzzle")
	local colors = {
		Gold = C.Gold,
		Black = Color3.fromRGB(16, 16, 18),
		Red = Color3.fromRGB(150, 20, 24),
		Blue = Color3.fromRGB(40, 70, 150),
	}
	local layout = { "Gold", "Black", "Red", "Blue" } -- physical order on the shelf
	local progress = {}
	local solved = false
	local books = {}
	for i, name in layout do
		local home = shelfCF * CFrame.new(-1.2 + (i - 1) * 0.8, 0, 0)
		local book = Build.P(m, Vector3.new(0.5, 1.9, 1.3), home, colors[name], M.Leather, { collide = false, name = name .. "Book" })
		Build.D(m, Vector3.new(0.52, 0.12, 1.32), home * CFrame.new(0, 0.6, 0), C.Gold, M.Metal)
		books[name] = { part = book, home = home }
		Interact.Add(book, { text = "اسحب", object = "الكتاب " .. ({ Red = "الأحمر", Gold = "الذهبي", Blue = "الأزرق", Black = "الأسود" })[name], dist = 6, los = false }, function(player)
			if solved or table.find(progress, name) then
				return
			end
			table.insert(progress, name)
			TweenService:Create(book, TweenInfo.new(0.25), { CFrame = home * CFrame.new(0, 0, -0.7) * CFrame.Angles(math.rad(-15), 0, 0) }):Play()
			Sounds.Play("Click", book)
			for index, pulled in progress do
				if Config.BookOrder[index] ~= pulled then
					task.wait(0.6)
					Sounds.Play("Locked", book)
					Run.Notify(player, "تنزلق الكتب عائدة إلى مكانها. ترتيب خاطئ.", "warn")
					for _, data in books do
						TweenService:Create(data.part, TweenInfo.new(0.3), { CFrame = data.home }):Play()
					end
					progress = {}
					return
				end
			end
			if #progress == #Config.BookOrder then
				solved = true
				Sounds.Play("Unlock", book)
				onSolved(player)
			end
		end)
	end
	return m
end

----------------------------------------------------------------------------------------
-- Basement generator: pour fuel, then pull the (loud) starter three times.
----------------------------------------------------------------------------------------

function Puzzles.Generator(model: Model, statusLight: BasePart, anchorPos: Vector3)
	local fuelled = false
	local pulls = 0
	local running = false
	local anchor = Interact.Anchor(model, anchorPos, "Anchor")
	local hum
	local prompt
	prompt = Interact.Add(anchor, { text = "افحص", object = "المولّد", dist = 8, hold = 0.5 }, function(player)
		if running then
			return
		end
		if not fuelled then
			if Inventory.Remove(player, "FuelCan", 1) then
				fuelled = true
				prompt.ActionText = "اسحب الحبل"
				prompt.HoldDuration = 1.5
				Run.Notify(player, "يتدفق الوقود في الخزان. اسحب حبل التشغيل.", "item")
				Sounds.Play("Paper", anchor, { PlaybackSpeed = 0.5 })
			else
				Run.Notify(player, "الخزان فارغ. ابحث عن وقود في المخزن السفلي.", "warn")
			end
			return
		end
		pulls += 1
		Sounds.Play("GeneratorStart", anchor)
		Run.Noise:Fire(anchor.Position, 2.5)
		if pulls < 3 then
			statusLight.Color = Color3.fromRGB(220, 160, 30)
			task.delay(0.4, function()
				statusLight.Color = Color3.fromRGB(120, 10, 10)
			end)
			Run.Notify(player, pulls == 1 and "يسعل ثم يموت. مرة أخرى!" or "تقريبًا... مرة أخرى!", "warn")
			return
		end
		running = true
		prompt.Enabled = false
		statusLight.Color = Color3.fromRGB(40, 220, 90)
		hum = Sounds.Make("Generator", anchor)
		if hum then
			hum:Play()
		end
		Run.SetFlag("generator", true)
	end)
end

----------------------------------------------------------------------------------------
-- Secret bookcase that slides aside (manager's office -> secret room)
----------------------------------------------------------------------------------------

function Puzzles.SlidingBookcase(bookcase: Model, offset: Vector3, flag: string)
	local start = bookcase:GetPivot()
	local value = Instance.new("CFrameValue")
	value.Value = start
	value.Changed:Connect(function(cf)
		bookcase:PivotTo(cf)
	end)
	value.Parent = bookcase
	local function open()
		Sounds.Play("Creak", bookcase.PrimaryPart or bookcase:FindFirstChildWhichIsA("BasePart"))
		TweenService:Create(value, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { Value = start + offset }):Play()
	end
	local conn = Run.FlagChanged:Connect(function(name, v)
		if name == flag and v then
			open()
		end
	end)
	bookcase.Destroying:Connect(function()
		conn.Disconnect()
	end)
	if Run.Flag(flag) then
		bookcase:PivotTo(start + offset)
	end
end

-- Crooked painting that acts as a hidden switch.
function Puzzles.Switch(part: BasePart, text: string, object: string, flag: string, message: string?)
	local prompt
	prompt = Interact.Add(part, { text = text, object = object, dist = 7, hold = 0.6, los = false }, function(player)
		if Run.Flag(flag) then
			return
		end
		prompt.Enabled = false
		Sounds.Play("Lever", part)
		if message then
			Run.Notify(player, message, "info")
		end
		Run.SetFlag(flag, true)
	end)
	return prompt
end

function Puzzles.Init()
	Net.Event("Keypad").OnServerEvent:Connect(function(player, id, code)
		if typeof(id) ~= "string" or typeof(code) ~= "string" or #code > 8 then
			return
		end
		if not Net.Allow(player, "keypad", 0.6) then
			return
		end
		local keypad = Puzzles.Keypads[id]
		if not keypad or keypad.solved or not Run.IsPlaying() then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - keypad.anchor.Position).Magnitude > 14 then
			return
		end
		if keypad.zone and not Power.IsOn(keypad.zone) then
			return
		end
		if code == keypad.code then
			Run.Notify(player, "تم السماح بالدخول.", "item")
			Puzzles.SolveKeypad(id, player)
		else
			Sounds.Play("Locked", keypad.anchor)
			keypad.screen.Color = Color3.fromRGB(200, 20, 20)
			task.delay(0.5, function()
				if not keypad.solved then
					keypad.screen.Color = Color3.fromRGB(40, 10, 10)
				end
			end)
			Run.Notify(player, "رمز خاطئ.", "warn")
		end
	end)
end

function Puzzles.Reset()
	Puzzles.Keypads = {}
end

return Puzzles
