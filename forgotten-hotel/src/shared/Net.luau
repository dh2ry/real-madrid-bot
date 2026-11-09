--!nonstrict
-- RemoteEvent registry. The server creates every remote up-front; clients wait for them.
-- Every client->server remote is validated and rate-limited on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Names = {
	-- server -> client
	"Notify", -- (text, kind)
	"Inventory", -- (itemsArray)
	"Objective", -- (index, missionId, progressText)
	"Document", -- (docId)
	"Cinematic", -- (name, data)
	"Achievement", -- (achievementId)
	"Profile", -- (profileSnapshot)
	"RunState", -- (stateTable)
	"Ending", -- (endingId, results)
	-- bidirectional
	"Keypad", -- s->c (keypadId, title, digits) / c->s (keypadId, code)
	"Choice", -- s->c (options) / c->s (choiceId)
	-- client -> server
	"Lobby", -- (action, arg)
	"Flashlight", -- (on)
	"Move", -- (mode)
	"Settings", -- (settingsTable)
	"EquipSkin", -- (skinId)
	"Hide", -- () leave hiding spot
	"UseItem", -- (itemId)
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		for _, name in Net.Names do
			if not f:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = f
			end
		end
		folder = f
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder :: Folder
end

function Net.Event(name: string): RemoteEvent
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

-- Server-side rate limiter: returns true when the call is allowed.
local lastCall: { [Player]: { [string]: number } } = {}
function Net.Allow(player: Player, key: string, interval: number): boolean
	local now = os.clock()
	local perPlayer = lastCall[player]
	if not perPlayer then
		perPlayer = {}
		lastCall[player] = perPlayer
	end
	if perPlayer[key] and now - perPlayer[key] < interval then
		return false
	end
	perPlayer[key] = now
	return true
end

function Net.Forget(player: Player)
	lastCall[player] = nil
end

return Net
