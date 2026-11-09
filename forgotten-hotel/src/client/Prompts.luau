--!nonstrict
-- Custom-styled ProximityPrompts (all server prompts use Style = Custom). Shows the key
-- (keyboard / gamepad) or a tappable button on touch screens, with a hold-progress bar.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)
local Theme = require(script.Parent.UI.Theme)

local Prompts = {}
local player = Players.LocalPlayer
local active: { [ProximityPrompt]: BillboardGui } = {}

local function keyLabel(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (name:gsub("Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "اضغط"
	end
	return prompt.KeyboardKeyCode.Name
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local C = Theme.Colors
	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(240, 62)
	gui.StudsOffset = Vector3.new(0, 1, 0)
	gui.Adornee = prompt.Parent
	gui.ResetOnSpawn = false
	gui.Active = inputType == Enum.ProximityPromptInputType.Touch

	local frame = Instance.new("TextButton")
	frame.Name = "Frame"
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = C.panel
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	Theme.Corner(frame, 8)
	Theme.Stroke(frame, C.gold, 1, 0.4)

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.Size = UDim2.fromOffset(44, 44)
	key.Position = UDim2.fromOffset(9, 9)
	key.BackgroundColor3 = C.burgundy
	key.TextColor3 = C.gold
	key.Font = Theme.Fonts.ui
	key.TextScaled = true
	key.Text = keyLabel(prompt, inputType)
	key.Parent = frame
	Theme.Corner(key, 6)
	Theme.Stroke(key, C.gold, 1, 0.2)
	Theme.TextLimit(key, 18)

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.BackgroundTransparency = 1
	action.Position = UDim2.fromOffset(62, 8)
	action.Size = UDim2.new(1, -70, 0, 26)
	action.Font = Theme.Fonts.title
	action.TextColor3 = C.text
	action.TextXAlignment = Enum.TextXAlignment.Right
	action.TextScaled = true
	action.Text = prompt.ActionText
	action.Parent = frame
	Theme.TextLimit(action, 22)

	local object = Instance.new("TextLabel")
	object.Name = "Object"
	object.BackgroundTransparency = 1
	object.Position = UDim2.fromOffset(62, 34)
	object.Size = UDim2.new(1, -70, 0, 18)
	object.Font = Theme.Fonts.body
	object.TextColor3 = C.dim
	object.TextXAlignment = Enum.TextXAlignment.Right
	object.TextScaled = true
	object.Text = prompt.ObjectText
	object.Parent = frame
	Theme.TextLimit(object, 16)

	local bar = Instance.new("Frame")
	bar.Name = "Hold"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = C.gold
	bar.Position = UDim2.new(0, 0, 1, -3)
	bar.Size = UDim2.new(0, 0, 0, 3)
	bar.Parent = frame

	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end)
		frame.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end)
	end

	local conns = {}
	table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = prompt.ActionText
	end))
	table.insert(conns, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		object.Text = prompt.ObjectText
	end))
	local holdTween
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			bar.Size = UDim2.new(0, 0, 0, 3)
			holdTween = TweenService:Create(bar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 0, 3) })
			holdTween:Play()
		end
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		bar.Size = UDim2.new(0, 0, 0, 3)
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		frame.BackgroundColor3 = C.burgundy
		TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundColor3 = C.panel }):Play()
	end))
	gui.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	frame.Size = UDim2.fromScale(0.85, 0.85)
	frame.Position = UDim2.fromScale(0.075, 0.075)
	TweenService:Create(frame, TweenInfo.new(0.12), { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }):Play()
	return gui
end

local function disableOwnPrompts(character: Model)
	local function check(d)
		if d:IsA("ProximityPrompt") then
			d.Enabled = false -- local only: you can't revive yourself
		end
	end
	for _, d in character:GetDescendants() do
		check(d)
	end
	character.DescendantAdded:Connect(check)
end

function Prompts.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		if active[prompt] then
			active[prompt]:Destroy()
		end
		active[prompt] = build(prompt, inputType)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local gui = active[prompt]
		if gui then
			active[prompt] = nil
			gui:Destroy()
		end
	end)
	-- no prompts while menus/cinematics are open
	State.Changed:Connect(function(key)
		if key == "MenuOpen" or key == "PanelOpen" or key == "Cinematic" then
			ProximityPromptService.Enabled = not State.InputBlocked()
		end
	end)
	ProximityPromptService.Enabled = not State.InputBlocked()
	player.CharacterAdded:Connect(disableOwnPrompts)
	if player.Character then
		disableOwnPrompts(player.Character)
	end
	local _ = UserInputService
end

return Prompts
