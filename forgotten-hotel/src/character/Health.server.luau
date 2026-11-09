--!nonstrict
-- Replaces Roblox's default "Health" regeneration script (same name in
-- StarterCharacterScripts overrides it). Regenerates slowly, only after the player has
-- not been hurt for a while, and never while downed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

while humanoid.Health > 0 and character.Parent do
	task.wait(1)
	if not character:GetAttribute("Downed") and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		local lastHurt = character:GetAttribute("LastHurt") or 0
		if workspace:GetServerTimeNow() - lastHurt > Config.Health.RegenDelay then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Health.RegenPerSecond)
		end
	end
end
