--!nonstrict
-- Input for PC (keyboard/mouse), gamepad and touch (ContextActionService creates the
-- on-screen buttons on mobile/tablet). Movement speed itself is server authoritative;
-- the client only requests a mode.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local State = require(script.Parent.State)

local Controls = {}
local player = Players.LocalPlayer
local sprintHeld = false
local crouchOn = false
local lastMode = "walk"
local handlers = {} -- external actions registered by other modules

local function sendMode()
	local mode = "walk"
	if crouchOn then
		mode = "crouch"
	elseif sprintHeld then
		mode = "sprint"
	end
	State.Set("Crouching", crouchOn)
	if mode ~= lastMode then
		lastMode = mode
		Net.Event("Move"):FireServer(mode)
	end
end

function Controls.On(action: string, fn: () -> ())
	handlers[action] = fn
end

local function fire(action: string)
	local fn = handlers[action]
	if fn then
		fn()
	end
end

local function bind(name: string, title: string, keys, callback, position: UDim2?)
	ContextActionService:BindAction(name, function(_, inputState, input)
		return callback(inputState, input)
	end, true, table.unpack(keys))
	ContextActionService:SetTitle(name, title)
	if position then
		ContextActionService:SetPosition(name, position)
	end
	local button = ContextActionService:GetButton(name)
	if button then
		button.Size = UDim2.fromOffset(62, 62)
	end
end

function Controls.Init()
	State.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local mobile = State.IsTouch

	bind("Sprint", "ركض", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }, function(inputState, input)
		if State.InputBlocked() then
			sprintHeld = false
			sendMode()
			return Enum.ContextActionResult.Pass
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if inputState == Enum.UserInputState.Begin then
				sprintHeld = not sprintHeld
				if sprintHeld then
					crouchOn = false
				end
			end
		else
			sprintHeld = inputState == Enum.UserInputState.Begin
			if sprintHeld then
				crouchOn = false
			end
		end
		sendMode()
		return Enum.ContextActionResult.Sink
	end, UDim2.new(1, -150, 1, -150))

	bind("Crouch", "تسلّل", { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB }, function(inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if State.InputBlocked() then
			return Enum.ContextActionResult.Pass
		end
		crouchOn = not crouchOn
		if crouchOn then
			sprintHeld = false
		end
		sendMode()
		return Enum.ContextActionResult.Sink
	end, UDim2.new(1, -220, 1, -110))

	local function tap(action: string)
		return function(inputState)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if action ~= "Menu" and action ~= "Inventory" and State.InputBlocked() then
				return Enum.ContextActionResult.Pass
			end
			fire(action)
			return Enum.ContextActionResult.Sink
		end
	end

	bind("Flashlight", "ضوء", { Enum.KeyCode.F, Enum.KeyCode.ButtonY }, tap("Flashlight"), UDim2.new(1, -90, 1, -215))
	bind("Battery", "بطارية", { Enum.KeyCode.R, Enum.KeyCode.DPadUp }, tap("Battery"), UDim2.new(1, -160, 1, -225))
	bind("Bandage", "علاج", { Enum.KeyCode.H, Enum.KeyCode.DPadDown }, tap("Bandage"), UDim2.new(1, -230, 1, -195))
	bind("CameraMode", "منظور", { Enum.KeyCode.V, Enum.KeyCode.DPadRight }, tap("CameraMode"), mobile and UDim2.new(0, 20, 0, 180) or nil)
	bind("Inventory", "حقيبة", { Enum.KeyCode.Tab, Enum.KeyCode.I, Enum.KeyCode.ButtonR1 }, tap("Inventory"), mobile and UDim2.new(0, 20, 0, 250) or nil)
	bind("Menu", "قائمة", { Enum.KeyCode.M, Enum.KeyCode.P, Enum.KeyCode.ButtonStart }, tap("Menu"), mobile and UDim2.new(0, 20, 0, 110) or nil)

	-- keep the server in sync after respawns
	player.CharacterAdded:Connect(function()
		sprintHeld = false
		crouchOn = false
		lastMode = ""
		sendMode()
	end)
	State.Changed:Connect(function(key)
		if (key == "MenuOpen" or key == "PanelOpen" or key == "Cinematic") and State.InputBlocked() then
			sprintHeld = false
			sendMode()
		end
	end)
	-- player attributes drive the sprint FOV
	player:GetAttributeChangedSignal("Stamina"):Connect(function()
		local character = player.Character
		State.Sprinting = character ~= nil and character:GetAttribute("Sprinting") == true
	end)
end

-- Hide/show touch buttons (e.g. during the main menu).
function Controls.SetVisible(visible: boolean)
	for _, name in { "Sprint", "Crouch", "Flashlight", "Battery", "Bandage", "CameraMode", "Inventory" } do
		local button = ContextActionService:GetButton(name)
		if button then
			button.Visible = visible
		end
	end
end

return Controls
