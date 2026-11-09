--!nonstrict
-- Individual, server-owned inventories. Clients only ever receive read-only snapshots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local Inventory = {}
Inventory.Data = {} :: { [Player]: { [string]: number } }
Inventory.Added = Signal.new() -- (player, itemId, count)

local function bag(player: Player)
	local data = Inventory.Data[player]
	if not data then
		data = {}
		Inventory.Data[player] = data
	end
	return data
end

function Inventory.Sync(player: Player)
	local list = {}
	for _, id in Items.Order do
		local count = bag(player)[id]
		if count and count > 0 then
			table.insert(list, { id = id, count = count })
		end
	end
	Net.Event("Inventory"):FireClient(player, list)
end

function Inventory.Count(player: Player, id: string): number
	return bag(player)[id] or 0
end

function Inventory.Has(player: Player, id: string): boolean
	return Inventory.Count(player, id) > 0
end

function Inventory.Add(player: Player, id: string, count: number?)
	if not Items[id] then
		warn("[Inventory] unknown item", id)
		return
	end
	local data = bag(player)
	local n = count or 1
	if not Items[id].stack then
		data[id] = 1
	else
		data[id] = (data[id] or 0) + n
	end
	Inventory.Sync(player)
	Inventory.Added:Fire(player, id, n)
end

function Inventory.Remove(player: Player, id: string, count: number?): boolean
	local data = bag(player)
	local have = data[id] or 0
	local n = count or 1
	if have < n then
		return false
	end
	data[id] = have - n
	if data[id] <= 0 then
		data[id] = nil
	end
	Inventory.Sync(player)
	return true
end

-- Returns the first participant holding the item (team-wide checks).
function Inventory.Holder(id: string): Player?
	for player, data in Inventory.Data do
		if player.Parent and (data[id] or 0) > 0 then
			return player
		end
	end
	return nil
end

function Inventory.Snapshot(player: Player): { [string]: number }
	return table.clone(bag(player))
end

function Inventory.Load(player: Player, snapshot: { [string]: number }?)
	local data = {}
	if snapshot then
		for id, count in snapshot do
			if Items[id] and typeof(count) == "number" and count > 0 then
				data[id] = math.floor(count)
			end
		end
	end
	Inventory.Data[player] = data
	Inventory.Sync(player)
end

function Inventory.Clear(player: Player)
	Inventory.Data[player] = {}
	if player.Parent then
		Inventory.Sync(player)
	end
end

function Inventory.Forget(player: Player)
	Inventory.Data[player] = nil
end

return Inventory
