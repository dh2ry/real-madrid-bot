--!nonstrict
-- Camera controller: orbiting menu camera, first/third person modes, FOV, sprint FOV kick,
-- crouch height, head bob and mouse sensitivity. Cinematics take over via State.Cinematic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)

local CameraController = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MENU_TARGET = Vector3.new(0, 20, -50)
local bobTime = 0
local currentOffset = Vector3.zero
local menuTime = 0

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function CameraController.ApplyMode()
	local mode = State.Settings.cameraMode
	if mode == "first" then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 6
		player.CameraMaxZoomDistance = 14
	end
end

function CameraController.Toggle()
	local Settings = require(script.Parent.Settings)
	Settings.Set("cameraMode", State.Settings.cameraMode == "first" and "third" or "first")
	CameraController.ApplyMode()
end

local function step(dt: number)
	camera = workspace.CurrentCamera
	UserInputService.MouseDeltaSensitivity = State.Settings.sensitivity
	if State.MenuOpen and not State.InRun() then
		-- slow orbit of the facade in the rain
		menuTime += dt
		camera.CameraType = Enum.CameraType.Scriptable
		local a = math.rad(-120) + math.sin(menuTime * 0.05) * 0.35
		local pos = MENU_TARGET + Vector3.new(math.cos(a) * 78, -8 + math.sin(menuTime * 0.13) * 2, math.sin(a) * 78 - 20)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(pos, MENU_TARGET), math.min(1, dt * 2))
		camera.FieldOfView = 60
		return
	end
	if State.Cinematic or State.Hidden then
		return
	end
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		local hum = humanoid()
		if hum then
			camera.CameraSubject = hum
		end
	end
	local hum = humanoid()
	if not hum then
		return
	end
	-- FOV with sprint kick
	local fov = State.Settings.fov + (State.Sprinting and 7 or 0)
	camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 6)
	-- crouch / downed height + head bob + third person shoulder offset
	local target = Vector3.zero
	if State.Downed then
		target = Vector3.new(0, -2.2, 0)
	elseif State.Crouching then
		target = Vector3.new(0, -1.6, 0)
	end
	if State.Settings.cameraMode == "third" then
		target += Vector3.new(1.6, 0.6, 0)
	end
	local root = hum.RootPart
	local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
	if State.Settings.headBob and State.Settings.cameraMode == "first" and speed > 1 and hum.FloorMaterial ~= Enum.Material.Air then
		bobTime += dt * speed * 0.55
		target += Vector3.new(math.cos(bobTime) * 0.08, math.abs(math.sin(bobTime)) * 0.16, 0)
	else
		bobTime = 0
	end
	currentOffset = currentOffset:Lerp(target, math.min(1, dt * 10))
	hum.CameraOffset = currentOffset
end

function CameraController.Init()
	CameraController.ApplyMode()
	RunService:BindToRenderStep("HotelCamera", Enum.RenderPriority.Camera.Value - 1, step)
	State.Changed:Connect(function(key)
		if key == "SettingsApplied" then
			CameraController.ApplyMode()
		elseif key == "MenuOpen" then
			if not State.MenuOpen then
				camera.CameraType = Enum.CameraType.Custom
				local hum = humanoid()
				if hum then
					camera.CameraSubject = hum
				end
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		task.defer(CameraController.ApplyMode)
	end)
end

return CameraController
