--!nonstrict
-- In-game HUD: health / stamina / flashlight battery, objective panel, inventory hotbar,
-- notifications, achievement toasts, subtitles, and full-screen overlays (vignette,
-- damage, downed, death, hiding, letterbox, flash).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local MissionDefs = require(Shared.Missions)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Config = require(Shared.Config)

local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local C, F = Theme.Colors, Theme.Fonts

local HUD = {}
local player = Players.LocalPlayer
local gui: ScreenGui
local overlay: ScreenGui
local refs = {}

local function tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

----------------------------------------------------------------------------------------
-- Bars (top-left)
----------------------------------------------------------------------------------------

local function bar(parent, order: number, icon: string, color: Color3, height: number)
	local row = Theme.New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height + 6), LayoutOrder = order, Parent = parent })
	Theme.Label(row, icon, { dims = UDim2.fromOffset(22, height + 6), font = F.ui, color = color, align = Enum.TextXAlignment.Center, max = 18 })
	local back = Theme.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 8, 9),
		BackgroundTransparency = 0.25,
		Position = UDim2.new(0, 28, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -28, 0, height),
		Parent = row,
	})
	Theme.Corner(back, 3)
	Theme.Stroke(back, C.gold, 1, 0.6)
	local fill = Theme.New("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), Parent = back })
	Theme.Corner(fill, 3)
	Theme.Gradient(fill, color, color:Lerp(Color3.new(0, 0, 0), 0.45), 90)
	local text = Theme.Label(back, "", { font = F.ui, color = C.text, align = Enum.TextXAlignment.Right, dims = UDim2.new(1, -6, 1, 0), max = 12, z = 3 })
	return fill, text, row
end

local function buildBars()
	local holder = Theme.New("Frame", {
		Name = "Vitals",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 18),
		Size = UDim2.new(0.22, 0, 0, 90),
		Parent = gui,
	})
	Theme.New("UISizeConstraint", { MinSize = Vector2.new(170, 0), MaxSize = Vector2.new(300, 200), Parent = holder })
	Theme.List(holder, 2)
	refs.health, refs.healthText = bar(holder, 1, "♥", Color3.fromRGB(170, 30, 36), 14)
	refs.stamina, _, refs.staminaRow = bar(holder, 2, "»", C.gold, 7)
	refs.battery, refs.batteryText = bar(holder, 3, "🔦", C.cold, 11)
	refs.vitals = holder
end

----------------------------------------------------------------------------------------
-- Objective (top-right)
----------------------------------------------------------------------------------------

local function buildObjective()
	local panel = Theme.New("Frame", {
		Name = "Objective",
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.new(0.28, 0, 0, 100),
		Parent = gui,
	})
	Theme.New("UISizeConstraint", { MinSize = Vector2.new(200, 0), MaxSize = Vector2.new(380, 200), Parent = panel })
	Theme.Corner(panel, 8)
	Theme.Stroke(panel, C.gold, 1, 0.6)
	Theme.Padding(panel, 10)
	refs.objHeader = Theme.Label(panel, "المهمة", { font = F.bold, color = C.gold, dims = UDim2.new(1, 0, 0, 14), max = 12 })
	refs.objTitle = Theme.Label(panel, "", { font = F.title, color = C.text, dims = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 16), max = 22 })
	refs.objDesc = Theme.Label(panel, "", { font = F.body, color = C.dim, dims = UDim2.new(1, 0, 0, 38), pos = UDim2.fromOffset(0, 42), max = 16, valign = Enum.TextYAlignment.Top })
	refs.objProgress = Theme.Label(panel, "", { font = F.ui, color = C.gold, dims = UDim2.new(1, 0, 0, 14), pos = UDim2.new(0, 0, 1, -14), max = 12 })
	refs.objective = panel
	panel.Visible = false
end

function HUD.Objective(index: number, id: string, progress: string?)
	local def = MissionDefs[index]
	if not def then
		refs.objective.Visible = false
		return
	end
	local changed = refs.objTitle.Text ~= def.title
	refs.objective.Visible = true
	refs.objHeader.Text = string.format("المهمة %d / %d", index, #MissionDefs)
	refs.objTitle.Text = def.title
	refs.objDesc.Text = def.desc
	refs.objProgress.Text = progress or ""
	if changed then
		refs.objective.Position = UDim2.new(1, 30, 0, 18)
		tween(refs.objective, 0.6, { Position = UDim2.new(1, -18, 0, 18) }, Enum.EasingStyle.Back)
		HUD.Banner("مهمة جديدة", def.title)
	end
end

----------------------------------------------------------------------------------------
-- Hotbar (bottom-centre)
----------------------------------------------------------------------------------------

local function buildHotbar()
	local bar = Theme.New("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.6, 0, 0, 58),
		Parent = gui,
	})
	local layout = Theme.List(bar, 6, true, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.hotbar = bar
end

function HUD.RefreshInventory()
	for _, child in refs.hotbar:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, entry in State.Inventory do
		local def = Items[entry.id]
		if def then
			local slot = Theme.New("TextButton", {
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = C.panel,
				BackgroundTransparency = 0.2,
				Size = UDim2.fromOffset(52, 52),
				LayoutOrder = i,
				Parent = refs.hotbar,
			})
			Theme.Corner(slot, 6)
			Theme.Stroke(slot, def.critical and C.gold or C.goldDim, 1, 0.3)
			Theme.Label(slot, def.icon, { dims = UDim2.new(1, 0, 0.7, 0), font = F.ui, align = Enum.TextXAlignment.Center, max = 26 })
			Theme.Label(slot, entry.count > 1 and ("x" .. entry.count) or "", { dims = UDim2.new(1, -4, 0.3, 0), pos = UDim2.fromScale(0, 0.7), font = F.bold, color = C.gold, align = Enum.TextXAlignment.Right, max = 12 })
			slot.Activated:Connect(function()
				if entry.id == "Battery" or entry.id == "Bandage" then
					Net.Event("UseItem"):FireServer(entry.id)
				else
					HUD.Notify(def.name .. " - " .. def.desc, "info")
				end
			end)
		end
	end
end

----------------------------------------------------------------------------------------
-- Notifications, toasts, banners, subtitles
----------------------------------------------------------------------------------------

local KIND_COLORS = {
	info = C.text,
	item = C.gold,
	warn = Color3.fromRGB(230, 180, 90),
	danger = C.danger,
	doc = Color3.fromRGB(220, 200, 160),
	objective = C.good,
}

function HUD.Notify(text: string, kind: string?)
	local holder = refs.feed
	local label = Theme.Label(holder, text, {
		dims = UDim2.new(1, 0, 0, 24),
		font = F.body,
		color = KIND_COLORS[kind or "info"] or C.text,
		align = Enum.TextXAlignment.Center,
		max = 20,
		order = math.floor(os.clock() * 100) % 1e6,
	})
	Theme.Stroke(label, Color3.new(0, 0, 0), 1, 0.4).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	label.TextTransparency = 1
	tween(label, 0.25, { TextTransparency = 0 })
	local children = {}
	for _, c in holder:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(children, c)
		end
	end
	if #children > 4 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(5, function()
		if label.Parent then
			tween(label, 0.6, { TextTransparency = 1 })
			task.wait(0.6)
			label:Destroy()
		end
	end)
	if kind == "danger" then
		Sounds.Play("Sting", nil, { Volume = 0.4 })
	end
end

function HUD.Banner(small: string, big: string)
	local b = refs.banner
	refs.bannerSmall.Text = small
	refs.bannerBig.Text = big
	b.Visible = true
	refs.bannerSmall.TextTransparency = 1
	refs.bannerBig.TextTransparency = 1
	tween(refs.bannerSmall, 0.5, { TextTransparency = 0 })
	tween(refs.bannerBig, 0.8, { TextTransparency = 0 })
	local token = os.clock()
	b:SetAttribute("Token", token)
	task.delay(3.4, function()
		if b:GetAttribute("Token") == token then
			tween(refs.bannerSmall, 0.8, { TextTransparency = 1 })
			tween(refs.bannerBig, 0.8, { TextTransparency = 1 })
		end
	end)
end

function HUD.Toast(title: string, desc: string)
	local toast = Theme.Panel(gui, {
		name = "Toast",
		dims = UDim2.fromOffset(320, 64),
		pos = UDim2.new(0.5, 0, 0, -80),
		anchor = Vector2.new(0.5, 0),
		z = 20,
	})
	Theme.Label(toast, "🏆", { dims = UDim2.fromOffset(50, 64), font = F.ui, align = Enum.TextXAlignment.Center, max = 30, z = 21 })
	Theme.Label(toast, "إنجاز جديد", { dims = UDim2.new(1, -60, 0, 14), pos = UDim2.fromOffset(54, 8), font = F.bold, color = C.gold, max = 11, z = 21 })
	Theme.Label(toast, title, { dims = UDim2.new(1, -60, 0, 22), pos = UDim2.fromOffset(54, 22), font = F.title, max = 20, z = 21 })
	Theme.Label(toast, desc, { dims = UDim2.new(1, -60, 0, 14), pos = UDim2.fromOffset(54, 44), font = F.body, color = C.dim, max = 13, z = 21 })
	Sounds.Play("Ding", nil, { PlaybackSpeed = 1.3, Volume = 0.5 })
	tween(toast, 0.5, { Position = UDim2.new(0.5, 0, 0, 16) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		tween(toast, 0.4, { Position = UDim2.new(0.5, 0, 0, -80) })
		task.wait(0.5)
		toast:Destroy()
	end)
end

function HUD.Subtitle(text: string, duration: number?, style: string?)
	local label = refs.subtitle
	label.Text = text
	label.Font = style == "whisper" and F.body or F.body
	label.TextColor3 = style == "whisper" and Color3.fromRGB(170, 180, 200) or (style == "voice" and C.gold or C.text)
	label.TextTransparency = 1
	tween(label, 0.3, { TextTransparency = 0 })
	local token = os.clock()
	label:SetAttribute("Token", token)
	task.delay(duration or 4, function()
		if label:GetAttribute("Token") == token then
			tween(label, 0.6, { TextTransparency = 1 })
		end
	end)
end

----------------------------------------------------------------------------------------
-- Overlays
----------------------------------------------------------------------------------------

function HUD.Flash(color: Color3?, duration: number?)
	local f = refs.flash
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.05
	tween(f, duration or 0.6, { BackgroundTransparency = 1 })
end

function HUD.Hurt(intensity: number)
	local v = refs.hurt
	v.Visible = true
	for _, strip in v:GetChildren() do
		if strip:IsA("Frame") then
			strip.BackgroundTransparency = 0
			tween(strip, 1.2, { BackgroundTransparency = 1 - 0 })
		end
	end
	v:SetAttribute("Until", os.clock() + 0.9 + intensity)
end

function HUD.SetDowned(on: boolean, seconds: number?)
	refs.downed.Visible = on
	if on then
		local endAt = os.clock() + (seconds or 45)
		task.spawn(function()
			while refs.downed.Visible do
				local left = math.max(0, endAt - os.clock())
				refs.downedTimer.Text = string.format("تنزف... %d", math.ceil(left))
				task.wait(0.2)
			end
		end)
	end
end

function HUD.Died(respawn: number)
	local d = refs.death
	d.Visible = true
	d.BackgroundTransparency = 1
	tween(d, 1.2, { BackgroundTransparency = 0.1 })
	refs.deathTitle.TextTransparency = 1
	tween(refs.deathTitle, 1.5, { TextTransparency = 0 })
	task.delay(respawn + 0.8, function()
		tween(d, 1, { BackgroundTransparency = 1 })
		tween(refs.deathTitle, 0.8, { TextTransparency = 1 })
		task.wait(1)
		d.Visible = false
	end)
end

function HUD.SetHidden(on: boolean, kind: string?)
	refs.hide.Visible = on
	refs.hideSlats.Visible = on and kind ~= "bed"
	refs.hideBed.Visible = on and kind == "bed"
end

function HUD.Letterbox(on: boolean)
	tween(refs.letterTop, 0.5, { Size = UDim2.new(1, 0, on and 0.09 or 0, 0) })
	tween(refs.letterBottom, 0.5, { Size = UDim2.new(1, 0, on and 0.09 or 0, 0) })
end

function HUD.SetVisible(visible: boolean)
	gui.Enabled = visible
end

local function buildOverlays()
	overlay = Theme.New("ScreenGui", {
		Name = "HotelOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	refs.vignette = Theme.Vignette(overlay, Color3.new(0, 0, 0), 0.75, 1)
	refs.hurt = Theme.Vignette(overlay, Color3.fromRGB(140, 0, 0), 0.9, 2)
	refs.hurt.Visible = false
	refs.threat = Theme.Vignette(overlay, Color3.fromRGB(60, 0, 0), 0.6, 2)
	-- hiding: wardrobe slats / under-bed darkness
	refs.hide = Theme.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3, Parent = overlay })
	refs.hideSlats = Theme.New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = refs.hide })
	for i = 0, 13 do
		Theme.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(14, 9, 7),
			Size = UDim2.new(1, 0, 1 / 14, -10),
			Position = UDim2.new(0, 0, i / 14, 0),
			ZIndex = 3,
			Parent = refs.hideSlats,
		})
	end
	refs.hideBed = Theme.New("Frame", { BackgroundColor3 = Color3.fromRGB(6, 5, 5), Size = UDim2.fromScale(1, 0.62), ZIndex = 3, Parent = refs.hide })
	Theme.Gradient(refs.hideBed, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 90).Transparency = NumberSequence.new(0, 0.15)
	local leave = Theme.Button(refs.hide, "اخرج  [E]", function()
		Net.Event("Hide"):FireServer()
	end, { dims = UDim2.fromOffset(170, 46), pos = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 1), z = 5 })
	leave.ZIndex = 5
	Theme.Label(refs.hide, "أنت مختبئ. ابقَ هادئًا. لا تدعه يراك وأنت تدخل.", { dims = UDim2.new(1, 0, 0, 22), pos = UDim2.new(0, 0, 1, -100), font = F.body, color = C.dim, align = Enum.TextXAlignment.Center, max = 18, z = 5 })
	-- letterbox
	refs.letterTop = Theme.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0, 0), ZIndex = 6, Parent = overlay })
	refs.letterBottom = Theme.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), ZIndex = 6, Parent = overlay })
	-- subtitles
	refs.subtitle = Theme.Label(overlay, "", {
		dims = UDim2.new(0.8, 0, 0, 34),
		pos = UDim2.new(0.5, 0, 0.8, 0),
		anchor = Vector2.new(0.5, 0.5),
		font = F.body,
		align = Enum.TextXAlignment.Center,
		max = 26,
		z = 7,
	})
	Theme.Stroke(refs.subtitle, Color3.new(0, 0, 0), 1.5, 0.2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	refs.subtitle.TextTransparency = 1
	-- downed
	refs.downed = Theme.New("Frame", { BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 8, Parent = overlay })
	Theme.Label(refs.downed, "لقد سقطت", { dims = UDim2.new(1, 0, 0, 60), pos = UDim2.fromScale(0, 0.38), font = F.title, color = C.text, align = Enum.TextXAlignment.Center, max = 54, z = 9 })
	refs.downedTimer = Theme.Label(refs.downed, "", { dims = UDim2.new(1, 0, 0, 26), pos = UDim2.fromScale(0, 0.38 + 0.08), font = F.body, color = C.dim, align = Enum.TextXAlignment.Center, max = 22, z = 9 })
	Theme.Label(refs.downed, "ازحف إلى مكان آمن. يمكن لأحد رفاقك إنعاشك.", { dims = UDim2.new(1, 0, 0, 22), pos = UDim2.fromScale(0, 0.38 + 0.13), font = F.body, color = C.dim, align = Enum.TextXAlignment.Center, max = 18, z = 9 })
	-- death
	refs.death = Theme.New("Frame", { BackgroundColor3 = Color3.fromRGB(5, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10, Parent = overlay })
	refs.deathTitle = Theme.Label(refs.death, "لقد متّ", { dims = UDim2.new(1, 0, 0, 80), pos = UDim2.fromScale(0, 0.42), font = F.horror, color = C.danger, align = Enum.TextXAlignment.Center, max = 80, z = 11 })
	-- flash
	refs.flash = Theme.New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = overlay })
end

----------------------------------------------------------------------------------------
-- Init / update
----------------------------------------------------------------------------------------

function HUD.Init()
	gui = Theme.New("ScreenGui", {
		Name = "HotelHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildOverlays()
	buildBars()
	buildObjective()
	buildHotbar()
	refs.feed = Theme.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.new(0.6, 0, 0, 120),
		Parent = gui,
	})
	local feedLayout = Theme.List(refs.feed, 2, false, Enum.HorizontalAlignment.Center)
	feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.banner = Theme.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.new(0.7, 0, 0, 80), Visible = false, Parent = gui })
	refs.bannerSmall = Theme.Label(refs.banner, "", { dims = UDim2.new(1, 0, 0, 18), font = F.bold, color = C.gold, align = Enum.TextXAlignment.Center, max = 14 })
	refs.bannerBig = Theme.Label(refs.banner, "", { dims = UDim2.new(1, 0, 0, 48), pos = UDim2.fromOffset(0, 20), font = F.title, color = C.text, align = Enum.TextXAlignment.Center, max = 42 })
	refs.crosshair = Theme.New("Frame", { BackgroundColor3 = C.text, BackgroundTransparency = 0.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), Parent = gui })
	Theme.Corner(refs.crosshair, 2)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local pct = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
			refs.health.Size = UDim2.fromScale(pct, 1)
			refs.healthText.Text = tostring(math.ceil(humanoid.Health))
		end
		local stamina = (player:GetAttribute("Stamina") or 100) / Config.Movement.StaminaMax
		refs.stamina.Size = UDim2.fromScale(stamina, 1)
		refs.staminaRow.Visible = stamina < 0.99
		local battery = player:GetAttribute("Battery") or 100
		refs.battery.Size = UDim2.fromScale(battery / 100, 1)
		refs.battery.BackgroundColor3 = battery < Config.Flashlight.LowBattery and C.danger or C.cold
		refs.batteryText.Text = string.format("%d%%%s", math.floor(battery), player:GetAttribute("FlashlightOn") and " يعمل" or "")
		refs.crosshair.Visible = State.Settings.cameraMode == "first" and not State.Hidden
		-- threat vignette pulses with the heartbeat
		local threat = State.Threat or 0
		local pulse = threat > 0.3 and (0.5 + 0.5 * math.sin(os.clock() * (4 + threat * 6))) or 0
		for _, strip in refs.threat:GetChildren() do
			strip.BackgroundTransparency = 1 - threat * (0.6 + pulse * 0.4)
		end
		if refs.hurt.Visible and os.clock() > (refs.hurt:GetAttribute("Until") or 0) then
			refs.hurt.Visible = false
		end
	end)

	State.Changed:Connect(function(key)
		if key == "Inventory" then
			HUD.RefreshInventory()
		end
	end)
	Net.Event("Notify").OnClientEvent:Connect(HUD.Notify)
	Net.Event("Objective").OnClientEvent:Connect(function(index, id, progress)
		State.Set("Mission", { index = index, id = id, progress = progress })
		HUD.Objective(index, id, progress)
	end)
	Net.Event("Inventory").OnClientEvent:Connect(function(list)
		State.Set("Inventory", list)
	end)
end

return HUD
