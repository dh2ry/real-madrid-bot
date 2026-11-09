--!nonstrict
-- Server-authoritative interaction layer built on ProximityPrompts (works on PC, mobile,
-- tablet and gamepad). Clients draw the prompts with a custom style (see client/Prompts).
-- Every trigger is re-validated here: alive, not downed, not hidden, in range, rate limited.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Run = require(script.Parent.Run)

local Interact = {}

local function positionOf(parent: Instance): Vector3
	if parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return Vector3.zero
end

function Interact.CanAct(player: Player, def): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if character:GetAttribute("Downed") and not def.allowDowned then
		return false
	end
	if character:GetAttribute("Hidden") and not def.allowHidden then
		return false
	end
	if not def.anyState and not Run.IsPlaying() then
		return false
	end
	return true
end

-- def: text, object, hold, dist, los, allowHidden, allowDowned, anyState, name
function Interact.Add(parent: Instance, def, callback: (Player, ProximityPrompt) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = def.name or "Interact"
	prompt.ActionText = def.text or "تفاعل"
	prompt.ObjectText = def.object or ""
	prompt.HoldDuration = def.hold or 0
	prompt.MaxActivationDistance = def.dist or 8
	prompt.RequiresLineOfSight = def.los ~= false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player: Player)
		if not Interact.CanAct(player, def) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if (root.Position - positionOf(parent)).Magnitude > prompt.MaxActivationDistance + 7 then
			return
		end
		if not Net.Allow(player, "interact", 0.2) then
			return
		end
		local ok, err = pcall(callback, player, prompt)
		if not ok then
			warn("[Interact] handler error:", err)
		end
	end)
	return prompt
end

-- Convenience: an invisible anchor part to hold a prompt at an exact position.
function Interact.Anchor(parent: Instance, position: Vector3, name: string?): BasePart
	local part = Instance.new("Part")
	part.Name = name or "PromptAnchor"
	part.Size = Vector3.new(0.6, 0.6, 0.6)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Position = position
	part.Parent = parent
	return part
end

return Interact
