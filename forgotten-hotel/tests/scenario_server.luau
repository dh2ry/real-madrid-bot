-- Full server playthrough: lobby -> all ten missions -> ending -> reset.
M.isServer = true
math.randomseed(7)
local failures = 0
local function check(cond, msg)
	if cond then
		print("  ok   " .. msg)
	else
		failures += 1
		print("  FAIL " .. msg)
	end
end
local function errorsSoFar()
	return M.errors and #M.errors or 0
end

runScript("ServerScriptService/Server/Main")
M.advance(2)
check(errorsSoFar() == 0, "server boots without errors")
local hotel = workspace:FindFirstChild("Hotel")
check(hotel ~= nil, "hotel model built")
print(string.format("  info hotel instances: %d", #hotel:GetDescendants()))

local Server = game:GetService("ServerScriptService").Server
local Run = require(Server.Services.Run)
local Missions = require(Server.Services.Missions)
local Inventory = require(Server.Services.Inventory)
local Monsters = require(Server.Monsters.Monsters)
local Doors = require(Server.Services.Doors)

-- player + character -------------------------------------------------------------
local Players = game:GetService("Players")
M.spawnCharacter = function(p)
	local char = Instance.new("Model")
	char.Name = p.Name
	local hum = Instance.new("Humanoid")
	hum.Health = 100
	hum.MaxHealth = 100
	hum.Parent = char
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(0, 3, -105)
	root.Parent = char
	char.PrimaryPart = root
	for _, n in { "Head", "RightHand" } do
		local part = Instance.new("Part")
		part.Name = n
		part.CFrame = CFrame.new(0, 4.5, -105)
		part.Parent = char
	end
	p.Character = char
	char.Parent = workspace
	M.signalFor(p, "CharacterAdded"):Fire(char)
end
local player = Instance.new("Player")
player.Name = "Tester"
player.DisplayName = "Tester"
player.UserId = 1
player.Parent = Players
M.signalFor(Players, "PlayerAdded"):Fire(player)
M.spawnCharacter(player)
M.advance(3)
check(errorsSoFar() == 0, "player joins without errors")

local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local function remote(name)
	return remotes:FindFirstChild(name)
end

local function root()
	return player.Character:FindFirstChild("HumanoidRootPart")
end
local function teleport(pos)
	player.Character:PivotTo(CFrame.new(pos))
end
local function promptPos(prompt)
	local parent = prompt.Parent
	if parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return parent.Position
end
local function findPrompt(object, action)
	for _, d in workspace:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.Enabled and string.find(d.ObjectText or "", object, 1, true) and (not action or d.ActionText == action) then
			return d
		end
	end
	return nil
end
local function trigger(object, action, offset)
	local prompt = findPrompt(object, action)
	if not prompt then
		check(false, "prompt exists: " .. object .. (action and (" / " .. action) or ""))
		return false
	end
	teleport(promptPos(prompt) + (offset or Vector3.new(0, 0, 0)))
	M.signalFor(prompt, "Triggered"):Fire(player)
	M.advance(0.6)
	return true
end
local function mission()
	local def = Missions.Current()
	return def and def.id or "none"
end
local function waitMission(id, maxTime)
	local t = 0
	while mission() ~= id and t < (maxTime or 10) do
		M.advance(0.5)
		t += 0.5
	end
	check(mission() == id, "mission is now '" .. id .. "'")
end

-- The mock has no wall geometry for raycasts (monsters see through walls), so during the
-- story walk-through monster hits are recorded instead of applied.
local Survival = require(Server.Services.Survival)
local realDamage = Survival.Damage
local hits = {}
Survival.Damage = function(_, amount, source)
	hits[source] = (hits[source] or 0) + 1
end

-- lobby -> run ---------------------------------------------------------------------
remote("Lobby").OnServerEvent:Fire(player, "Difficulty", "Normal")
M.advance(0.5)
remote("Lobby").OnServerEvent:Fire(player, "Play")
M.advance(1)
check(Run.State == "Playing", "run started")
check(mission() == "enter", "mission 1 active")

-- 1. enter
teleport(Vector3.new(0, 3, -30))
waitMission("reception_key", 8)
M.advance(4)
check(Doors.Get("FrontDoor").locked, "front door slammed and locked")

-- 2. reception key
trigger("مفتاح الاستقبال")
check(Inventory.Has(player, "ReceptionKey"), "picked up reception key")
waitMission("power")

-- 3. power
trigger("مكتب الاستقبال")
check(not Doors.Get("ReceptionOfficeDoor").locked, "reception office unlocked with key")
trigger("فيوز خزفي")
trigger("القاطع الرئيسي")
trigger("القاطع الرئيسي", "اسحب الذراع")
check(Run.Flag("power") == true, "power restored")
waitMission("elevator_card")
M.advance(10)

-- 4. elevator card
trigger("مكتب الأمن", "أدخل الرمز")
remote("Keypad").OnServerEvent:Fire(player, "Security", "0000")
M.advance(1)
check(Doors.Get("SecurityDoor").locked, "wrong code rejected")
remote("Keypad").OnServerEvent:Fire(player, "Security", "1931")
M.advance(1)
check(not Doors.Get("SecurityDoor").locked, "security door opened with 1931")
trigger("بطاقة المصعد")
waitMission("room307")

-- elevator to F1
trigger("لوحة المصعد")
check(Run.Flag("elevator") == true, "access card inserted")
local car = workspace.Hotel.Elevator.ElevatorCar
teleport(car:GetPivot().Position + Vector3.new(0, 3, 0))
remote("Choice").OnServerEvent:Fire(player, "elevator", "F1")
M.advance(8)
check(root().Position.Y > 16 and root().Position.Y < 25, "rode the elevator to the first floor (y=" .. math.floor(root().Position.Y) .. ")")

-- 5. room 307 chain: laundry passage -> library books -> journal I -> photo -> safe
trigger("لوح جدار مخلخل")
check(Run.Flag("passage") == true, "hidden passage opened")
trigger("أنشودة التدبير المنزلي")
trigger("الحاجز")
check(not Doors.Get("LibraryDoor").barricaded, "library barricade removed from inside")
for _, colour in { "الذهبي", "الأحمر" } do
	trigger("الكتاب " .. colour)
end
check(Run.Flag("books") ~= true, "wrong book order resets")
M.advance(2)
for _, colour in { "الأحمر", "الذهبي", "الأزرق", "الأسود" } do
	trigger("الكتاب " .. colour)
end
check(Run.Flag("books") == true, "book puzzle solved")
trigger("مذكرات إلياس فارن - الجزء الأول")
trigger("صورة فوتوغرافية")
trigger("خزنة المدير", "أدخل الرمز")
remote("Keypad").OnServerEvent:Fire(player, "ManagerSafe", "2704")
M.advance(1)
check(Run.Flag("safeOpen") == true, "manager safe opened with 2704")
trigger("مفتاح الغرفة 307")
check(Inventory.Has(player, "Key307"), "got key 307")
trigger("لوحة مائلة")
M.advance(3)
check(Run.Flag("secretRoom") == true, "secret room revealed")
trigger("مذكرات إلياس فارن - الجزء الثاني")

-- third floor: shadow corridor event
teleport(Vector3.new(0, 51, 20))
M.advance(16)
check(Monsters.ShadowMode() == "upper", "shadow activated on the third floor")
check(Monsters.Shadow.active, "shadow spawned")
trigger("الغرفة 307")
check(not Doors.Get("Room307").locked, "room 307 unlocked")
trigger("مذكرات إلياس فارن - الجزء الثالث")
trigger("قلادة لينا")
check(Inventory.Has(player, "Locket"), "took Lina's locket")
M.advance(1)
trigger("المرآة")
check(Run.Flag("mirror") == true, "mirror scare triggered")
waitMission("documents", 8)
waitMission("basement", 10)

-- 7. phone call -> basement key
M.advance(3)
teleport(Vector3.new(0, 3, -4))
trigger("هاتف الاستقبال")
M.advance(12)
trigger("مفتاح القبو")
check(Inventory.Has(player, "BasementKey"), "concierge left the basement key")
trigger("القبو")
waitMission("generator")
check(Monsters.ShadowMode() == "basement", "shadow hunts the basement")

-- 8. generator
trigger("ملاحظة صيانة")
trigger("علبة وقود")
trigger("المولّد")
for _ = 1, 3 do
	trigger("المولّد", "اسحب الحبل")
end
check(Run.Flag("generator") == true, "generator running")
waitMission("lab")

-- 9. laboratory
trigger("المختبر", "أدخل الرمز")
remote("Keypad").OnServerEvent:Fire(player, "Laboratory", "0703")
M.advance(1)
check(not Doors.Get("LabDoor").locked, "lab door opened with 0703")
teleport(Vector3.new(-40, -11, 5))
waitMission("exit")
trigger("تقرير المختبر رقم 47")

-- 10. final choice + escape
local before = M.clientEvents and #M.clientEvents or 0
trigger("لوحة تحكم القلب")
local offered = false
for i = before + 1, #(M.clientEvents or {}) do
	local e = M.clientEvents[i]
	if e.remote == "Choice" and e.args[1] == "final" then
		offered = true
	end
end
check(offered, "final choice offered")
remote("Choice").OnServerEvent:Fire(player, "final", "destroy")
M.advance(4)
check(Run.Flag("finalChoice") == "destroy", "heart destroyed")
check(Monsters.ShadowMode() == "escape", "escape chase started")
check(not Doors.Get("ExitGate").locked, "exit gate opened")
teleport(Vector3.new(-95, -11, -30))
M.advance(3)
check(Run.Flag("escaped") == true, "player escaped")
M.advance(14)
check(Run.State == "Ending", "ending reached")
local endingSent = nil
for _, e in M.clientEvents or {} do
	if e.remote == "Ending" then
		endingSent = e.args[1]
	end
end
check(endingSent == "liberation", "liberation ending sent (" .. tostring(endingSent) .. ")")
M.advance(32)
check(Run.State == "Lobby", "world reset back to the lobby")
check(workspace:FindFirstChild("Hotel") ~= nil, "hotel rebuilt")

for source, n in hits do
	print(string.format("  info %s attacked the tester %d times during the walk-through", source, n))
end
Survival.Damage = realDamage

-- second run: continue + downed/death path ---------------------------------------
remote("Lobby").OnServerEvent:Fire(player, "Play")
M.advance(2)
check(Run.State == "Playing", "second run started")
Survival.Damage(player, 500, "Test")
M.advance(1)
check(player.Character:FindFirstChildOfClass("Humanoid").Health <= 0, "solo player dies instead of going down")

print("")
for _, line in M.log do
	print("  log  " .. line)
end
if M.errors then
	for _, e in M.errors do
		print("ERROR " .. e)
	end
end
print(string.format("\nRESULT: %d failed checks, %d runtime errors", failures, errorsSoFar()))
