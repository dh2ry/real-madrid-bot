-- Client smoke test: boots every client controller and drives the UI through the
-- server->client events of a whole run (menu, lobby, HUD, panels, ending).
M.isServer = false
math.randomseed(3)
local failures = 0
local function check(cond, msg)
	print((cond and "  ok   " or "  FAIL ") .. msg)
	if not cond then
		failures += 1
	end
end
local function errors()
	return M.errors and #M.errors or 0
end
local Me = M.Methods
-- client-only engine services
Me.BindAction = function() end
Me.SetTitle = function() end
Me.SetPosition = function() end
Me.GetButton = function()
	return Instance.new("TextButton")
end
Me.SetCoreGuiEnabled = function() end
local renderSteps = {}
Me.BindToRenderStep = function(_, _, _, fn)
	table.insert(renderSteps, fn)
end
local RunService = game:GetService("RunService")
local function frames(n)
	for _ = 1, n do
		for _, fn in renderSteps do
			fn(1 / 60)
		end
		M.signalFor(RunService, "RenderStepped"):Fire(1 / 60)
		M.signalFor(RunService, "Heartbeat"):Fire(1 / 60)
		M.signalFor(RunService, "Stepped"):Fire(0, 1 / 60)
		M.advance(1 / 60)
	end
end
Me.PromptGameInvite = function() end
Me.Disable = function() end
Me.Enable = function() end
Me.RemoveDefaultLoadingScreen = function() end
local UIS = game:GetService("UserInputService")
UIS.TouchEnabled = false
UIS.KeyboardEnabled = true
workspace.CurrentCamera = Instance.new("Camera")
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, -100)
workspace.CurrentCamera.FieldOfView = 70

-- remotes as the server would create them
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = game:GetService("ReplicatedStorage")
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
for _, name in Net.Names do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
for _, name in { "SFX", "Music", "Ambience" } do
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Parent = game:GetService("SoundService")
end

local player = Instance.new("Player")
player.Name = "Tester"
player.UserId = 1
player.Parent = game:GetService("Players")
local pg = Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = player
local ps = Instance.new("PlayerScripts")
ps.Name = "PlayerScripts"
ps.Parent = player
game:GetService("Players").LocalPlayer = player
M.localPlayer = player
local char = Instance.new("Model")
local hum = Instance.new("Humanoid")
hum.Parent = char
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Parent = char
local head = Instance.new("Part")
head.Name = "Head"
head.Parent = char
char.Parent = workspace
player.Character = char

local function fire(name, ...)
	M.signalFor(remotes:FindFirstChild(name), "OnClientEvent"):Fire(...)
	M.advance(0.3)
end

runScript("StarterPlayer/StarterPlayerScripts/Client/Main")
M.advance(2)
check(errors() == 0, "client boots")
check(pg:FindFirstChild("HotelMenu") ~= nil and pg:FindFirstChild("HotelHUD") ~= nil, "menu + HUD created")

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local State = require(Client.State)
local Menu = require(Client.UI.Menu)
local Panels = require(Client.UI.Panels)

fire("Profile", { coins = 120, achievements = { checked_in = 1 }, docs = { welcome_card = true }, endings = { escape = true }, skins = { classic = true, gold = true }, skin = "classic", settings = {}, stats = { runs = 2 }, hasSave = true, online = false })
fire("RunState", { state = "Lobby", host = 1, difficulty = "Normal", players = { { userId = 1, name = "Tester", ready = false }, { userId = 2, name = "Friend", ready = true } }, mission = 0, canContinue = true, continueMission = 4 })
check(State.MenuOpen, "menu open in lobby")

-- click through every menu button and settings / extras tab
local function clickAll(root, depth)
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextButton" and not d.Modal then
			M.signalFor(d, "Activated"):Fire()
			M.signalFor(d, "MouseEnter"):Fire()
			M.advance(0.05)
		end
	end
end
clickAll(pg:FindFirstChild("HotelMenu"))
M.advance(1)
check(errors() == 0, "menu buttons, lobby, settings and extras tabs work")

fire("RunState", { state = "Playing", host = 1, difficulty = "Nightmare", players = { { userId = 1, name = "Tester", ready = false, inRun = true } }, mission = 1 })
check(not State.MenuOpen, "menu closes when the run starts")
fire("Objective", 3, "power", nil)
fire("Objective", 6, "documents", "المذكرات التي وُجدت: 1/3")
fire("Inventory", { { id = "ReceptionKey", count = 1 }, { id = "Battery", count = 2 } })
fire("Notify", "التقطت: بطارية", "item")
fire("Achievement", "lights_on")
fire("Cinematic", "Subtitle", { text = "اختبار", duration = 1 })
fire("Cinematic", "Hurt", { amount = 30 })
fire("Cinematic", "Spotted", {})
fire("Cinematic", "Downed", { time = 10 })
fire("Cinematic", "Revived", {})
fire("Cinematic", "HideView", { cf = CFrame.new(0, 5, 0), kind = "wardrobe" })
fire("Cinematic", "Unhide", { forced = true })
fire("Cinematic", "Shake", { intensity = 1, duration = 1 })
fire("Cinematic", "Lightning", { seed = 4 })
fire("Cinematic", "LookAt", { position = Vector3.new(0, 5, 0), duration = 0.5 })
fire("Cinematic", "Died", { respawn = 1 })
M.advance(5)
-- a monster rig nearby so the animator + threat code run
local Rig = require(game:GetService("ServerScriptService").Server.Monsters.Rig)
for _, make in { Rig.Shadow, Rig.Concierge, Rig.Roomkeeper } do
	local model = make()
	model:SetAttribute("Chasing", true)
	model:SetAttribute("TargetId", 1)
	model:SetAttribute("Anim", "run")
	model.Parent = workspace
	game:GetService("CollectionService"):AddTag(model, "MonsterRig")
end
player:SetAttribute("FlashlightOn", true)
player:SetAttribute("Battery", 5)
frames(120)
check(errors() == 0, "HUD + cinematics + per-frame controllers run")

fire("Document", "journal_3")
check(State.PanelOpen == "Document", "document reader opens")
fire("Keypad", "Security", "مكتب الأمن", 4)
check(State.PanelOpen == "Keypad", "keypad opens")
clickAll(pg:FindFirstChild("HotelPanels"))
fire("Choice", "elevator", { current = "G", floors = { "G", "F1", "F2", "F3" }, labels = { G = "أ", F1 = "1", F2 = "2", F3 = "3" }, names = { G = "الطابق الأرضي", F1 = "1", F2 = "2", F3 = "3" } })
check(State.PanelOpen == "Elevator", "elevator panel opens")
Panels.Close()
fire("Choice", "final", { options = { { id = "seal", title = "اختم القلب", desc = "..." }, { id = "destroy", title = "دمّر القلب", desc = "...", disabled = true } } })
check(State.PanelOpen == "FinalChoice", "final choice opens")
Panels.Close()
Panels.Inventory()
check(State.PanelOpen == "Inventory", "inventory opens")
Panels.Close()
fire("Ending", "secret", { coins = 300, documents = 12, time = 1834, difficulty = "Nightmare", untouched = true, escaped = true })
M.advance(10)
check(State.PanelOpen == "Ending", "ending screen shows")
fire("RunState", { state = "Lobby", host = 1, difficulty = "Normal", players = { { userId = 1, name = "Tester" } }, mission = 0 })
M.advance(1)
check(State.MenuOpen and State.PanelOpen == nil, "back to the menu after the ending")
check(errors() == 0, "no client runtime errors")

for _, line in M.log do
	print("  log  " .. line)
end
for _, e in M.errors or {} do
	print("ERROR " .. e)
end
print(string.format("\nRESULT: %d failed checks, %d runtime errors", failures, errors()))
