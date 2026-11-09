--!nonstrict
-- Client-side state store shared between controllers and UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local State = {
	Profile = nil,
	RunState = { state = "Lobby", players = {}, host = 0, difficulty = "Normal", mission = 0 },
	Inventory = {},
	Mission = { index = 0, id = "", progress = nil },
	Settings = table.clone(Config.DefaultSettings),
	MenuOpen = true,
	PanelOpen = nil :: string?,
	Cinematic = false,
	Hidden = false,
	Downed = false,
	Threat = 0,
	Crouching = false,
	Sprinting = false,
	IsTouch = false,
	Changed = Signal.new(), -- (key, value)
}

function State.Set(key: string, value: any)
	State[key] = value
	State.Changed:Fire(key, value)
end

function State.InRun(): boolean
	local localPlayer = game:GetService("Players").LocalPlayer
	if State.RunState.state ~= "Playing" then
		return false
	end
	for _, p in State.RunState.players or {} do
		if p.userId == localPlayer.UserId then
			return p.inRun == true
		end
	end
	return false
end

-- True while gameplay input should be ignored (menus, panels, cinematics).
function State.InputBlocked(): boolean
	return State.MenuOpen or State.PanelOpen ~= nil or State.Cinematic
end

return State
