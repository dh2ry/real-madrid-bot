--!nonstrict
-- Local flashlight. The server owns the on/off state and battery (player attributes);
-- the owner renders a smooth camera-attached beam with shadows, everyone else sees the
-- replicated head light. Low battery makes the beam stutter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)
local Sounds = require(Shared.Sounds)
local State = require(script.Parent.State)

local Flashlight = {}
local player = Players.LocalPlayer
local holder: Part
local beam: SpotLight
local fill: PointLight
local smoothed = CFrame.new()

local function isOn(): boolean
	return player:GetAttribute("FlashlightOn") == true
end

local function hideServerLight()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light and light:IsA("Light") then
		light.Enabled = false
	end
end

function Flashlight.Toggle()
	if State.Hidden or State.Downed then
		return
	end
	Sounds.Play("Click")
	Net.Event("Flashlight"):FireServer(not isOn())
end

local function skinColor(): Color3
	local profile = State.Profile
	local skin = profile and Progression.Skins[profile.skin] or Progression.Skins.classic
	return skin.beam
end

function Flashlight.Init()
	holder = Instance.new("Part")
	holder.Name = "LocalFlashlight"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = workspace
	beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = Config.Flashlight.Range
	beam.Angle = Config.Flashlight.Angle
	beam.Brightness = Config.Flashlight.Brightness
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = holder
	fill = Instance.new("PointLight")
	fill.Range = 7
	fill.Brightness = 0.25
	fill.Shadows = false
	fill.Enabled = false
	fill.Parent = holder

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local on = isOn() and not State.Hidden and head ~= nil
		local target
		if State.Settings.cameraMode == "first" or not head then
			target = camera.CFrame * CFrame.new(0.5, -0.45, -0.6)
		else
			local look = camera.CFrame.LookVector
			target = CFrame.lookAt(head.Position + look * 1.2 + Vector3.new(0, -0.3, 0), head.Position + look * 20)
		end
		-- slight lag gives the beam weight
		smoothed = smoothed:Lerp(target, math.min(1, dt * 18))
		holder.CFrame = smoothed
		local battery = player:GetAttribute("Battery") or 100
		local flicker = false
		if on and battery < Config.Flashlight.LowBattery then
			flicker = math.random() < (0.08 + (Config.Flashlight.LowBattery - battery) / 60)
		end
		beam.Enabled = on and not flicker
		fill.Enabled = beam.Enabled
		beam.Color = skinColor()
		beam.Brightness = Config.Flashlight.Brightness * (battery < Config.Flashlight.LowBattery and 0.7 or 1)
		beam.Shadows = State.Settings.shadows
	end)

	player.CharacterAdded:Connect(function(character)
		local head = character:WaitForChild("Head", 10)
		if head then
			head.ChildAdded:Connect(function(child)
				if child.Name == "Flashlight" then
					task.defer(hideServerLight)
					child:GetPropertyChangedSignal("Enabled"):Connect(function()
						if child.Enabled then
							child.Enabled = false
						end
					end)
				end
			end)
			hideServerLight()
			local existing = head:FindFirstChild("Flashlight")
			if existing then
				existing:GetPropertyChangedSignal("Enabled"):Connect(function()
					if existing.Enabled then
						existing.Enabled = false
					end
				end)
			end
		end
	end)
end

return Flashlight
