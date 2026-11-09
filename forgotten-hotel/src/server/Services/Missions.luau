--!nonstrict
-- Story progression. Missions are completed by story flags, item pickups and documents.
-- Conditions met early (out of order) are remembered and complete instantly when their
-- mission becomes active, so co-op players can split up freely.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local MissionDefs = require(Shared.Missions)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local Run = require(script.Parent.Run)
local Inventory = require(script.Parent.Inventory)

local Missions = {}
Missions.Index = 0
Missions.DoneIndex = 0
Missions.Satisfied = {} :: { [string]: boolean }
Missions.Completed = Signal.new() -- (id, index)
Missions.Started = Signal.new() -- (id, index)

local startHooks: { [string]: { (boolean) -> () } } = {}
local completeHooks: { [string]: { () -> () } } = {}
local restoreHooks: { [string]: { () -> () } } = {}

local FLAG_TO_MISSION = {
	entered = "enter",
	power = "power",
	mirror = "room307",
	basementOpen = "basement",
	generator = "generator",
	labEntered = "lab",
	escaped = "exit",
}
local ITEM_TO_MISSION = {
	ReceptionKey = "reception_key",
	ElevatorCard = "elevator_card",
}

function Missions.OnStart(id: string, fn: (boolean) -> ())
	startHooks[id] = startHooks[id] or {}
	table.insert(startHooks[id], fn)
end

function Missions.OnComplete(id: string, fn: () -> ())
	completeHooks[id] = completeHooks[id] or {}
	table.insert(completeHooks[id], fn)
end

-- Effects to re-apply when a saved run is continued past this mission.
function Missions.OnRestore(id: string, fn: () -> ())
	restoreHooks[id] = restoreHooks[id] or {}
	table.insert(restoreHooks[id], fn)
end

function Missions.Current()
	return MissionDefs[Missions.Index]
end

function Missions.IsDone(id: string): boolean
	for i, def in MissionDefs do
		if def.id == id then
			return i < Missions.Index or (i == Missions.Index and Missions.Satisfied[id] == true)
		end
	end
	return false
end

local function progressText(def): string?
	if not def then
		return nil
	end
	if def.id == "documents" then
		return string.format("المذكرات التي وُجدت: %d/3", Run.JournalCount())
	end
	return nil
end

function Missions.Broadcast(player: Player?)
	local def = Missions.Current()
	local remote = Net.Event("Objective")
	local id = def and def.id or ""
	local progress = progressText(def)
	if player then
		remote:FireClient(player, Missions.Index, id, progress)
	else
		for p in Run.Participants do
			if p.Parent then
				remote:FireClient(p, Missions.Index, id, progress)
			end
		end
	end
end

local function runHooks(list, ...)
	for _, fn in list or {} do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Missions] hook error:", err)
		end
	end
end

function Missions.Start(index: number, restoring: boolean?)
	if not Run.IsPlaying() then
		return
	end
	Missions.Index = index
	local def = MissionDefs[index]
	if not def then
		return
	end
	Missions.Broadcast()
	Missions.Started:Fire(def.id, index)
	runHooks(startHooks[def.id], restoring == true)
	if Missions.Satisfied[def.id] then
		task.delay(1.5, Missions.Complete, def.id)
	end
end

function Missions.Complete(id: string)
	local def = Missions.Current()
	if not def or def.id ~= id or not Run.IsPlaying() then
		Missions.Satisfied[id] = true
		return
	end
	if Missions.DoneIndex == Missions.Index then
		return
	end
	Missions.DoneIndex = Missions.Index
	Missions.Satisfied[id] = true
	local index = Missions.Index
	Run.Notify(nil, "اكتملت المهمة: " .. def.title, "objective")
	runHooks(completeHooks[id])
	Missions.Completed:Fire(id, index)
	if index < #MissionDefs then
		task.delay(3, function()
			if Missions.Index == index and Run.IsPlaying() then
				Missions.Start(index + 1)
			end
		end)
	end
end

-- Re-applies effects of missions 1..index-1, then starts mission `index`.
function Missions.Restore(index: number)
	for i = 1, index - 1 do
		local def = MissionDefs[i]
		Missions.Satisfied[def.id] = true
		runHooks(restoreHooks[def.id])
	end
	Missions.Start(index, true)
end

function Missions.Reset()
	Missions.Index = 0
	Missions.DoneIndex = 0
	Missions.Satisfied = {}
end

function Missions.Init()
	Run.FlagChanged:Connect(function(name, value)
		local id = FLAG_TO_MISSION[name]
		if id and value then
			Missions.Complete(id)
		end
	end)
	Inventory.Added:Connect(function(_, itemId)
		local id = ITEM_TO_MISSION[itemId]
		if id then
			Missions.Complete(id)
		end
	end)
	Run.DocFound:Connect(function()
		local def = Missions.Current()
		if def and def.id == "documents" then
			Missions.Broadcast()
		end
		if Run.JournalCount() >= 3 then
			Missions.Complete("documents")
		end
	end)
end

return Missions
