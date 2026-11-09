--!nonstrict
-- Health, downed/revive, death & checkpoints, stamina, server-authoritative movement speed,
-- flashlight battery and noise (which the monsters listen to).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)
local Progression = require(Shared.Progression)

local Run = require(script.Parent.Run)
local Interact = require(script.Parent.Interact)
local Inventory = require(script.Parent.Inventory)
local Data = require(script.Parent.Data)

local Survival = {}

type State = {
	mode: string,
	stamina: number,
	exhausted: boolean,
	battery: number,
	flashlight: boolean,
	downedUntil: number?,
	revivePrompt: ProximityPrompt?,
}

local states: { [Player]: State } = {}
local MOVE = Config.Movement

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = {
			mode = "walk",
			stamina = MOVE.StaminaMax,
			exhausted = false,
			battery = Config.Flashlight.BatteryMax,
			flashlight = false,
			downedUntil = nil,
			revivePrompt = nil,
		}
		states[player] = s
	end
	return s
end

local function getHumanoid(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

----------------------------------------------------------------------------------------
-- Flashlight
----------------------------------------------------------------------------------------

local function skinOf(player: Player)
	local profile = Data.Get(player)
	local skinId = profile and profile.skin or "classic"
	return Progression.Skins[skinId] or Progression.Skins.classic
end

function Survival.ApplySkin(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local skin = skinOf(player)
	local head = character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light then
		light.Color = skin.beam
	end
	local body = character:FindFirstChild("FlashlightBody")
	if body then
		body.Color = skin.body
	end
end

local function setupFlashlight(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Range = Config.Flashlight.Range
	light.Angle = Config.Flashlight.Angle
	light.Brightness = Config.Flashlight.Brightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = head

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		local body = Instance.new("Part")
		body.Name = "FlashlightBody"
		body.Shape = Enum.PartType.Cylinder
		body.Size = Vector3.new(1.1, 0.35, 0.35)
		body.Material = Enum.Material.Metal
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		body.Massless = true
		local offset = hand.Name == "RightHand" and CFrame.new(0, -0.25, -0.4) or CFrame.new(0, -0.9, -0.4)
		body.CFrame = hand.CFrame * offset * CFrame.Angles(0, math.rad(90), 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = body
		weld.Parent = body
		body.Parent = character
	end
	Survival.ApplySkin(player)
end

local function setFlashlight(player: Player, on: boolean)
	local s = state(player)
	if on and s.battery <= 0 then
		Run.Notify(player, "بطارية مصباحك فارغة. ابحث عن بطارية (R للاستخدام).", "warn")
		on = false
	end
	s.flashlight = on
	player:SetAttribute("FlashlightOn", on)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light then
		light.Enabled = on
	end
	if character then
		character:SetAttribute("Lit", on)
	end
end
Survival.SetFlashlight = setFlashlight

----------------------------------------------------------------------------------------
-- Damage / downed / revive
----------------------------------------------------------------------------------------

local function othersStanding(except: Player): number
	local n = 0
	for _, entry in Run.Characters(false) do
		if entry.player ~= except then
			n += 1
		end
	end
	return n
end

function Survival.IsDowned(player: Player): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Downed") == true
end

function Survival.Kill(player: Player)
	local character, humanoid = getHumanoid(player)
	if not character or not humanoid then
		return
	end
	local s = state(player)
	if s.revivePrompt then
		s.revivePrompt:Destroy()
		s.revivePrompt = nil
	end
	s.downedUntil = nil
	humanoid.Health = 0
	Data.Stat(player, "deaths", 1)
	Run.Cinematic(player, "Died", { respawn = Players.RespawnTime })
end

function Survival.Revive(player: Player, reviver: Player?)
	local character, humanoid = getHumanoid(player)
	if not character or not humanoid or not character:GetAttribute("Downed") then
		return
	end
	local s = state(player)
	if s.revivePrompt then
		s.revivePrompt:Destroy()
		s.revivePrompt = nil
	end
	s.downedUntil = nil
	character:SetAttribute("Downed", false)
	humanoid.Health = Config.Health.ReviveHealth
	humanoid.JumpPower = 30
	Run.Cinematic(player, "Revived", nil)
	if reviver then
		Run.Notify(nil, reviver.DisplayName .. " أنعش " .. player.DisplayName .. ".", "info")
		Data.Award(reviver, "rescuer")
	end
end

function Survival.Down(player: Player)
	local character, humanoid, root = getHumanoid(player)
	if not character or not humanoid or not root then
		return
	end
	local s = state(player)
	character:SetAttribute("Downed", true)
	Run.DownedThisRun[player] = true
	humanoid.Health = 1
	humanoid.JumpPower = 0
	s.downedUntil = os.clock() + Run.Diff().downedTime
	setFlashlight(player, false)
	s.revivePrompt = Interact.Add(root, {
		text = "أنعش",
		object = player.DisplayName,
		hold = Config.Health.ReviveHoldTime,
		dist = 8,
		los = false,
		name = "RevivePrompt",
	}, function(reviver)
		if reviver ~= player then
			Survival.Revive(player, reviver)
		end
	end)
	Run.Notify(nil, player.DisplayName .. " سقط! اضغط مطولًا على E بجانبه لإنعاشه.", "danger")
	Run.Cinematic(player, "Downed", { time = Run.Diff().downedTime })
end

-- The only way monsters hurt players. Handles downed state instead of instant death.
function Survival.Damage(player: Player, amount: number, source: string?)
	local character, humanoid = getHumanoid(player)
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if character:GetAttribute("Downed") then
		return
	end
	local dmg = amount * Run.Diff().damage
	character:SetAttribute("LastHurt", workspace:GetServerTimeNow())
	Run.Cinematic(player, "Hurt", { amount = dmg, source = source })
	if humanoid.Health - dmg > 0.5 then
		humanoid.Health -= dmg
		return
	end
	if othersStanding(player) > 0 then
		Survival.Down(player)
	else
		Run.DownedThisRun[player] = true
		Survival.Kill(player)
	end
end

function Survival.Heal(player: Player, amount: number)
	local _, humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

----------------------------------------------------------------------------------------
-- Spawning / checkpoints
----------------------------------------------------------------------------------------

function Survival.SendToCheckpoint(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local index = table.find(Players:GetPlayers(), player) or 1
	local angle = index * (math.pi * 2 / Config.MaxPlayers)
	local offset = Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5)
	character:PivotTo(Run.Checkpoint + offset)
end

function Survival.ResetPlayer(player: Player)
	local s = state(player)
	s.stamina = MOVE.StaminaMax
	s.exhausted = false
	s.battery = Config.Flashlight.BatteryMax
	s.mode = "walk"
	setFlashlight(player, false)
	player:SetAttribute("Battery", s.battery)
	player:SetAttribute("Stamina", s.stamina)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = Config.Health.Max
	humanoid.Health = Config.Health.Max
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 30
	humanoid.WalkSpeed = MOVE.WalkSpeed
	character:SetAttribute("Downed", false)
	character:SetAttribute("Hidden", false)
	character:SetAttribute("Noise", 0)
	local s = state(player)
	s.downedUntil = nil
	s.revivePrompt = nil
	s.mode = "walk"
	s.stamina = MOVE.StaminaMax
	task.spawn(setupFlashlight, player, character)
	setFlashlight(player, false)
	if Run.IsPlaying() and Run.Participants[player] then
		task.defer(function()
			if character.Parent then
				Survival.SendToCheckpoint(player)
			end
		end)
	end
	humanoid.Died:Connect(function()
		setFlashlight(player, false)
	end)
end

----------------------------------------------------------------------------------------
-- Tick
----------------------------------------------------------------------------------------

local function tick(dt: number)
	local diff = Run.Diff()
	local anyStanding = false
	local anyDowned = false
	for _, player in Players:GetPlayers() do
		local s = state(player)
		local character, humanoid, root = getHumanoid(player)
		if character and humanoid and root and humanoid.Health > 0 then
			local downed = character:GetAttribute("Downed") == true
			local hidden = character:GetAttribute("Hidden") == true
			local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			local moving = horizontal > 2
			local sprinting = false
			if downed then
				anyDowned = Run.Participants[player] == true or anyDowned
				humanoid.WalkSpeed = MOVE.DownedSpeed
				if s.downedUntil and os.clock() > s.downedUntil then
					Survival.Kill(player)
				end
			elseif hidden then
				humanoid.WalkSpeed = 0
				anyStanding = anyStanding or Run.Participants[player] == true
			else
				anyStanding = anyStanding or Run.Participants[player] == true
				if s.mode == "sprint" and not s.exhausted and s.stamina > 0 and moving then
					sprinting = true
					s.stamina = math.max(0, s.stamina - MOVE.StaminaDrain * dt)
					if s.stamina <= 0 then
						s.exhausted = true
						Run.Cinematic(player, "Exhausted", nil)
					end
				else
					s.stamina = math.min(MOVE.StaminaMax, s.stamina + MOVE.StaminaRegen * dt * (moving and 0.6 or 1))
					if s.exhausted and s.stamina >= MOVE.ExhaustRecover then
						s.exhausted = false
					end
				end
				if sprinting then
					humanoid.WalkSpeed = MOVE.SprintSpeed
				elseif s.mode == "crouch" then
					humanoid.WalkSpeed = MOVE.CrouchSpeed
				else
					humanoid.WalkSpeed = MOVE.WalkSpeed
				end
			end
			-- noise heard by monsters
			local noise = 0
			if moving and not hidden then
				if downed then
					noise = 0.2
				elseif sprinting then
					noise = MOVE.Noise.sprint
				elseif s.mode == "crouch" then
					noise = MOVE.Noise.crouch
				else
					noise = MOVE.Noise.walk
				end
			end
			character:SetAttribute("Noise", noise)
			character:SetAttribute("Sprinting", sprinting)
			-- flashlight battery
			if s.flashlight and Run.IsPlaying() then
				s.battery = math.max(0, s.battery - diff.battery * dt)
				if s.battery <= 0 then
					setFlashlight(player, false)
					Run.Notify(player, "انطفأ المصباح.", "warn")
				end
			end
			player:SetAttribute("Battery", math.floor(s.battery * 10) / 10)
			player:SetAttribute("Stamina", math.floor(s.stamina))
		end
	end
	-- team wipe: nobody left standing -> the downed bleed out immediately
	if Run.IsPlaying() and anyDowned and not anyStanding then
		for _, player in Players:GetPlayers() do
			if Survival.IsDowned(player) then
				Survival.Kill(player)
			end
		end
		Run.Notify(nil, "سقط الجميع. العودة إلى آخر نقطة حفظ...", "danger")
	end
end

function Survival.Init()
	Players.RespawnTime = 5
	Players.PlayerAdded:Connect(function(player)
		state(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		state(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Net.Event("Move").OnServerEvent:Connect(function(player, mode)
		if typeof(mode) ~= "string" or not MOVE.Noise[mode] or mode == "idle" then
			return
		end
		if not Net.Allow(player, "move", 0.05) then
			return
		end
		state(player).mode = mode
		player:SetAttribute("MoveMode", mode)
	end)

	Net.Event("Flashlight").OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" or not Net.Allow(player, "flashlight", 0.15) then
			return
		end
		local character = player.Character
		if on and character and (character:GetAttribute("Downed") or character:GetAttribute("Hidden")) then
			on = false
		end
		setFlashlight(player, on)
		local head = character and character:FindFirstChild("Head")
		if head then
			Sounds.Play("Click", head)
		end
	end)

	Net.Event("UseItem").OnServerEvent:Connect(function(player, itemId)
		if typeof(itemId) ~= "string" or not Net.Allow(player, "useitem", 0.5) then
			return
		end
		local character, humanoid = getHumanoid(player)
		if not character or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Downed") then
			return
		end
		if itemId == "Battery" then
			local s = state(player)
			if s.battery >= Config.Flashlight.BatteryMax - 1 then
				Run.Notify(player, "البطارية ممتلئة بالفعل.", "info")
			elseif Inventory.Remove(player, "Battery", 1) then
				s.battery = Config.Flashlight.BatteryMax
				player:SetAttribute("Battery", s.battery)
				Run.Notify(player, "تم تبديل بطارية المصباح.", "item")
			else
				Run.Notify(player, "ليس لديك بطاريات.", "warn")
			end
		elseif itemId == "Bandage" then
			if humanoid.Health >= humanoid.MaxHealth - 1 then
				Run.Notify(player, "أنت لست مصابًا.", "info")
			elseif Inventory.Remove(player, "Bandage", 1) then
				Survival.Heal(player, Config.Health.BandageHeal)
				Run.Notify(player, "تضمّد جراحك.", "item")
			else
				Run.Notify(player, "ليس لديك ضمادات.", "warn")
			end
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			if not ok then
				warn("[Survival] tick error:", err)
			end
			last = now
		end
	end)
end

return Survival
