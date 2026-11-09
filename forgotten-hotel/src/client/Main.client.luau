--!nonstrict
-- THE FORGOTTEN HOTEL - client bootstrap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)

local State = require(script.Parent.State)
local Settings = require(script.Parent.Settings)
local CameraController = require(script.Parent.Camera)
local Controls = require(script.Parent.Controls)
local Flashlight = require(script.Parent.Flashlight)
local Prompts = require(script.Parent.Prompts)
local Audio = require(script.Parent.Audio)
local Cinematics = require(script.Parent.Cinematics)
local MonsterAnimator = require(script.Parent.MonsterAnimator)
local HUD = require(script.Parent.UI.HUD)
local Panels = require(script.Parent.UI.Panels)
local Menu = require(script.Parent.UI.Menu)

local player = Players.LocalPlayer

-- the hotel provides its own HUD; keep the chat and player list
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- server state -> client state (connect before anything can arrive)
Net.Event("Profile").OnClientEvent:Connect(function(profile)
	State.Set("Profile", profile)
end)
Net.Event("RunState").OnClientEvent:Connect(function(runState)
	State.Set("RunState", runState)
end)
Net.Event("Achievement").OnClientEvent:Connect(function(id)
	local def = Progression.Achievements[id]
	if def then
		HUD.Toast(def.name, def.desc)
	end
end)

Settings.Init()
HUD.Init()
Panels.Init()
Menu.Init()
CameraController.Init()
Controls.Init()
Flashlight.Init()
Prompts.Init()
Audio.Init()
Cinematics.Init()
MonsterAnimator.Init()

-- actions
Controls.On("Flashlight", Flashlight.Toggle)
Controls.On("Battery", function()
	Net.Event("UseItem"):FireServer("Battery")
end)
Controls.On("Bandage", function()
	Net.Event("UseItem"):FireServer("Bandage")
end)
Controls.On("CameraMode", CameraController.Toggle)
Controls.On("Inventory", function()
	if not State.MenuOpen then
		Panels.Inventory()
	end
end)
Controls.On("Menu", Menu.Toggle)

-- HUD + touch buttons only while actually playing; character controls frozen in menus
local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and module then
		controls = module:GetControls()
	end
end)

local function refreshMode()
	local playing = State.InRun() and not State.MenuOpen
	HUD.SetVisible(playing)
	Controls.SetVisible(playing)
	if controls then
		if State.MenuOpen or State.PanelOpen == "Ending" then
			controls:Disable()
		else
			controls:Enable()
		end
	end
end
State.Changed:Connect(function(key)
	if key == "MenuOpen" or key == "RunState" or key == "PanelOpen" then
		refreshMode()
	end
end)
refreshMode()
