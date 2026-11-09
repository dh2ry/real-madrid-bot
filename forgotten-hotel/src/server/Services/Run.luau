--!nonstrict
-- Shared run state: session state, difficulty, story flags, team documents, checkpoints
-- and named map points. Has no dependencies on other server services.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local Net = require(Shared.Net)

local Run = {}

Run.State = "Lobby" -- "Lobby" | "Playing" | "Ending"
Run.Difficulty = "Normal"
Run.Flags = {} :: { [string]: any }
Run.Docs = {} :: { [string]: boolean }
Run.Participants = {} :: { [Player]: boolean }
Run.Points = {} :: { [string]: CFrame }
Run.Checkpoint = CFrame.new(0, 3, -100)
Run.StartTime = 0
Run.Map = nil :: Model?
Run.DownedThisRun = {} :: { [Player]: boolean }
-- Map data registered by the hotel builder (rebuilt with the map)
Run.Waypoints = {} :: { [string]: { Vector3 } } -- monster patrol nodes per floor
Run.ConciergeSpots = {} :: { { cf: CFrame, floor: string } }
Run.Zones = {} :: { [string]: any } -- Roomkeeper restricted rooms

Run.FlagChanged = Signal.new() -- (name, value)
Run.StateChanged = Signal.new() -- (state)
Run.DocFound = Signal.new() -- (docId, player)
Run.Noise = Signal.new() -- (position, loudness) loud world events monsters can hear

function Run.Diff()
	return Config.Difficulty[Run.Difficulty] or Config.Difficulty.Normal
end

function Run.SetFlag(name: string, value: any)
	if Run.Flags[name] == value then
		return
	end
	Run.Flags[name] = value
	Run.FlagChanged:Fire(name, value)
end

function Run.Flag(name: string): any
	return Run.Flags[name]
end

function Run.SetState(state: string)
	Run.State = state
	Run.StateChanged:Fire(state)
end

function Run.IsPlaying(): boolean
	return Run.State == "Playing"
end

function Run.SetPoint(name: string, cf: CFrame)
	Run.Points[name] = cf
end

function Run.Point(name: string): CFrame
	return Run.Points[name] or Run.Checkpoint
end

function Run.SetCheckpoint(name: string)
	local cf = Run.Points[name]
	if cf then
		Run.Checkpoint = cf
		Run.Flags.checkpoint = name
	end
end

function Run.DocCount(): number
	local n = 0
	for _ in Run.Docs do
		n += 1
	end
	return n
end

function Run.JournalCount(): number
	local n = 0
	for _, id in { "journal_1", "journal_2", "journal_3" } do
		if Run.Docs[id] then
			n += 1
		end
	end
	return n
end

-- Characters of participants that are alive (downed included unless excluded).
function Run.Characters(includeDowned: boolean?): { { player: Player, character: Model, root: BasePart, humanoid: Humanoid } }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Run.Participants[player] then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				if includeDowned or not character:GetAttribute("Downed") then
					table.insert(list, { player = player, character = character, root = root, humanoid = humanoid })
				end
			end
		end
	end
	return list
end

function Run.FloorsWithPlayers(): { [string]: number }
	local floors = {}
	for _, entry in Run.Characters(false) do
		local floor = Config.FloorAt(entry.root.Position.Y)
		floors[floor] = (floors[floor] or 0) + 1
	end
	return floors
end

function Run.Notify(target: Player?, text: string, kind: string?)
	local remote = Net.Event("Notify")
	if target then
		remote:FireClient(target, text, kind or "info")
	else
		remote:FireAllClients(text, kind or "info")
	end
end

function Run.Cinematic(target: Player? | { Player }, name: string, data: any?)
	local remote = Net.Event("Cinematic")
	if target == nil then
		for player in Run.Participants do
			if player.Parent then
				remote:FireClient(player, name, data)
			end
		end
	elseif typeof(target) == "table" then
		for _, player in target :: { Player } do
			remote:FireClient(player, name, data)
		end
	else
		remote:FireClient(target :: Player, name, data)
	end
end

function Run.ResetMapData()
	Run.Points = {}
	Run.Waypoints = {}
	Run.ConciergeSpots = {}
	Run.Zones = {}
end

function Run.AddWaypoint(floor: string, position: Vector3)
	Run.Waypoints[floor] = Run.Waypoints[floor] or {}
	table.insert(Run.Waypoints[floor], position)
end

function Run.ResetState()
	Run.Flags = {}
	Run.Docs = {}
	Run.Participants = {}
	Run.DownedThisRun = {}
	Run.StartTime = 0
end

return Run
