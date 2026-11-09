--!nonstrict
-- Client side of every scripted moment: camera look-ats and focus shots, shakes, flashes,
-- subtitles, hurt/downed/death feedback, hiding views, elevator rides and lightning.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local State = require(script.Parent.State)
local HUD = require(script.Parent.UI.HUD)

local Cinematics = {}
local player = Players.LocalPlayer
local shakeUntil, shakeIntensity = 0, 0
local hideCF: CFrame? = nil
local hideYaw, hidePitch = 0, 0
local busy = 0

local function camera()
	return workspace.CurrentCamera
end

local function beginOverride()
	busy += 1
	State.Set("Cinematic", true)
	HUD.Letterbox(true)
	camera().CameraType = Enum.CameraType.Scriptable
end

local function endOverride()
	busy = math.max(0, busy - 1)
	if busy == 0 then
		HUD.Letterbox(false)
		State.Set("Cinematic", false)
		if not State.Hidden then
			local cam = camera()
			cam.CameraType = Enum.CameraType.Custom
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				cam.CameraSubject = humanoid
			end
		end
	end
end

local function tweenCamera(target: CFrame, time: number)
	local cam = camera()
	local tween = TweenService:Create(cam, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = target })
	tween:Play()
	tween.Completed:Wait()
end

local handlers = {}

handlers.LookAt = function(data)
	if State.Hidden or State.MenuOpen then
		return
	end
	local cam = camera()
	local position: Vector3 = data.position
	beginOverride()
	local from = cam.CFrame
	tweenCamera(CFrame.lookAt(from.Position, position), 0.45)
	task.wait(data.duration or 2)
	-- turn the character to face what they just saw so control resumes naturally
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(position.X, root.Position.Y, position.Z))
	end
	endOverride()
end

handlers.Focus = function(data)
	if State.Hidden then
		return
	end
	beginOverride()
	tweenCamera(data.cf, 0.8)
	task.wait(data.duration or 3)
	endOverride()
end

handlers.Shake = function(data)
	shakeIntensity = math.max(shakeIntensity, data.intensity or 0.4)
	shakeUntil = math.max(shakeUntil, os.clock() + (data.duration or 0.5))
end

handlers.Scare = function(data)
	HUD.Flash(data and data.color or Color3.fromRGB(255, 255, 255), 0.5)
	Sounds.Play("Sting", nil, { Volume = 1 })
	handlers.Shake({ intensity = 0.8, duration = 0.5 })
end

handlers.Subtitle = function(data)
	HUD.Subtitle(data.text, data.duration, data.voice and "voice" or nil)
end

handlers.Whisper = function(data)
	HUD.Subtitle(data.text, 3.5, "whisper")
	if not data.quiet then
		Sounds.Play("Whisper", nil, { Volume = 0.8 })
	end
end

handlers.Hurt = function(data)
	HUD.Hurt(math.clamp((data.amount or 20) / 40, 0.2, 1))
	Sounds.Play("Hit", nil, { Volume = 0.9 })
	handlers.Shake({ intensity = 0.7, duration = 0.35 })
end

handlers.Spotted = function()
	Sounds.Play("Sting", nil, { Volume = 0.8 })
	HUD.Flash(Color3.fromRGB(80, 0, 0), 0.4)
end

handlers.Downed = function(data)
	State.Set("Downed", true)
	HUD.SetDowned(true, data.time)
end

handlers.Revived = function()
	State.Set("Downed", false)
	HUD.SetDowned(false)
	HUD.Notify("عدتَ إلى الوقوف على قدميك.", "item")
end

handlers.Died = function(data)
	State.Set("Downed", false)
	HUD.SetDowned(false)
	HUD.Died(data.respawn or 5)
	Sounds.Play("Scream", nil, { Volume = 0.6, PlaybackSpeed = 0.4 })
end

handlers.Exhausted = function()
	Sounds.Play("Breathing", nil, { Looped = false, Volume = 0.6, PlaybackSpeed = 0.8 })
	HUD.Notify("انقطعت أنفاسك.", "warn")
end

handlers.ElevatorRide = function(data)
	handlers.Shake({ intensity = 0.15, duration = data.duration or 3 })
end

handlers.HideView = function(data)
	State.Set("Hidden", true)
	hideCF = data.cf
	hideYaw, hidePitch = 0, 0
	camera().CameraType = Enum.CameraType.Scriptable
	HUD.SetHidden(true, data.kind)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

handlers.Unhide = function(data)
	State.Set("Hidden", false)
	hideCF = nil
	HUD.SetHidden(false)
	local cam = camera()
	if not State.Cinematic then
		cam.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
	if data and data.forced then
		handlers.Scare({ color = Color3.fromRGB(120, 0, 0) })
	end
end

handlers.Lightning = function(data)
	local rng = Random.new(data and data.seed or 1)
	local grade = Lighting:FindFirstChild("Grade")
	local baseAmbient = Lighting.OutdoorAmbient
	local baseBrightness = Lighting.Brightness
	for _ = 1, rng:NextInteger(1, 3) do
		Lighting.OutdoorAmbient = Color3.fromRGB(190, 200, 230)
		Lighting.Brightness = 3
		if grade then
			grade.Brightness = 0.12
		end
		task.wait(0.05 + rng:NextNumber() * 0.08)
		Lighting.OutdoorAmbient = baseAmbient
		Lighting.Brightness = baseBrightness
		if grade then
			grade.Brightness = 0.02
		end
		task.wait(0.06 + rng:NextNumber() * 0.15)
	end
	task.wait(0.8 + rng:NextNumber() * 2)
	Sounds.Play("Thunder", nil, { Volume = 1.5 + rng:NextNumber() })
end

function Cinematics.Play(name: string, data)
	local handler = handlers[name]
	if handler then
		task.spawn(handler, data or {})
	end
end

function Cinematics.Init()
	Net.Event("Cinematic").OnClientEvent:Connect(Cinematics.Play)

	-- hiding: limited free-look through the gap
	UserInputService.InputChanged:Connect(function(input)
		if hideCF and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Delta
			hideYaw = math.clamp(hideYaw - delta.X * 0.004 * State.Settings.sensitivity, -0.6, 0.6)
			hidePitch = math.clamp(hidePitch - delta.Y * 0.004 * State.Settings.sensitivity, -0.35, 0.35)
		end
	end)

	RunService:BindToRenderStep("HotelCinematicFX", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = camera()
		if hideCF then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = hideCF * CFrame.Angles(0, hideYaw, 0) * CFrame.Angles(hidePitch, 0, 0)
		end
		local now = os.clock()
		if now < shakeUntil then
			local fade = math.clamp((shakeUntil - now) * 2, 0, 1)
			local i = shakeIntensity * fade
			cam.CFrame = cam.CFrame * CFrame.Angles(
				(math.random() - 0.5) * 0.04 * i,
				(math.random() - 0.5) * 0.04 * i,
				(math.random() - 0.5) * 0.03 * i
			)
		else
			shakeIntensity = 0
		end
	end)

	player.CharacterAdded:Connect(function()
		State.Set("Downed", false)
		State.Set("Hidden", false)
		hideCF = nil
		HUD.SetHidden(false)
		HUD.SetDowned(false)
		if busy > 0 then
			busy = 1
			endOverride()
		end
	end)
end

return Cinematics
