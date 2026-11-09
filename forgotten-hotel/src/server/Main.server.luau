--!nonstrict
-- THE FORGOTTEN HOTEL - server bootstrap.
-- Initialises collision groups, sound groups, remotes and every service, then builds the
-- hotel and opens the lobby.

local PhysicsService = game:GetService("PhysicsService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)

-- collision groups ------------------------------------------------------------------
for _, group in { "Monsters", "Doors", "Debris" } do
	if not PhysicsService:IsCollisionGroupRegistered(group) then
		PhysicsService:RegisterCollisionGroup(group)
	end
end
PhysicsService:CollisionGroupSetCollidable("Monsters", "Doors", false)
PhysicsService:CollisionGroupSetCollidable("Monsters", "Debris", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Doors", false)

-- sound groups (volumes are adjusted per player on the client) ------------------------
for _, name in { "SFX", "Music", "Ambience" } do
	if not SoundService:FindFirstChild(name) then
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Volume = 1
		group.Parent = SoundService
	end
end
SoundService.RespectFilteringEnabled = true

Players.CharacterAutoLoads = true

-- remotes ---------------------------------------------------------------------------
Net.Event("Notify") -- creates the Remotes folder with every RemoteEvent

-- services --------------------------------------------------------------------------
local Services = script.Parent.Services
local Power = require(Services.Power)
local Data = require(Services.Data)
local Survival = require(Services.Survival)
local Hiding = require(Services.Hiding)
local Puzzles = require(Services.Puzzles)
local Elevator = require(Services.Elevator)
local Missions = require(Services.Missions)
local Events = require(Services.Events)
local Session = require(Services.Session)
local Run = require(Services.Run)
local Monsters = require(script.Parent.Monsters.Monsters)

Power.Init()
Survival.Init()
Hiding.Init()
Puzzles.Init()
Elevator.Init()
Missions.Init()
Monsters.Init()
Events.Init()
Session.Init()

local started = os.clock()
Session.BuildWorld()
print(string.format("[ForgottenHotel] hotel built in %.2fs (%d parts)", os.clock() - started, #workspace.Hotel:GetDescendants()))

Data.Init(Survival.ApplySkin)
Run.SetState("Lobby")
Session.Broadcast()
