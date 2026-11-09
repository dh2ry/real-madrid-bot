--!nonstrict
-- Hotel electricity. Every light tagged "HotelLight" belongs to a zone (G, F1, F2, F3, B,
-- Escape). Zones are switched by story progress; lights can flicker, be faulty
-- (flicker forever) or switch to emergency red.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Power = {}
Power.Zones = {} :: { [string]: boolean }
Power.Lights = {} :: { Light }

local bulbs: { [Light]: { BasePart } } = {}
local flickering: { [Light]: boolean } = {}
local originalColor: { [Light]: Color3 } = {}

local function findBulbs(light: Light)
	local list = {}
	local parent = light.Parent
	if parent and parent:IsA("BasePart") and parent.Material == Enum.Material.Neon then
		table.insert(list, parent)
	end
	local model = parent and parent:FindFirstAncestorOfClass("Model")
	if model and model.Name ~= "Hotel" then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Bulb" and not table.find(list, d) then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function setVisual(light: Light, on: boolean)
	light.Enabled = on
	for _, bulb in bulbs[light] or {} do
		bulb.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		bulb.Transparency = on and 0 or 0.2
	end
end

local function register(light: Instance)
	if not light:IsA("Light") or bulbs[light] then
		return
	end
	bulbs[light] = findBulbs(light)
	originalColor[light] = light.Color
	table.insert(Power.Lights, light)
	local zone = light:GetAttribute("Zone")
	setVisual(light, zone ~= nil and Power.Zones[zone] == true)
end

function Power.Init()
	CollectionService:GetInstanceAddedSignal("HotelLight"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("HotelLight"):Connect(function(light)
		bulbs[light] = nil
		flickering[light] = nil
		originalColor[light] = nil
		local i = table.find(Power.Lights, light)
		if i then
			table.remove(Power.Lights, i)
		end
	end)
	-- faulty lights flicker on their own forever
	task.spawn(function()
		while true do
			task.wait(0.12)
			for _, light in Power.Lights do
				if light:GetAttribute("Faulty") and not flickering[light] and Power.Zones[light:GetAttribute("Zone")] then
					if math.random() < 0.18 then
						setVisual(light, not light.Enabled)
					elseif not light.Enabled and math.random() < 0.5 then
						setVisual(light, true)
					end
				end
			end
		end
	end)
end

-- Registers lights that already exist (call after the map is built).
function Power.Scan()
	for _, light in CollectionService:GetTagged("HotelLight") do
		register(light)
	end
end

function Power.IsOn(zone: string): boolean
	return Power.Zones[zone] == true
end

function Power.SetZone(zone: string, on: boolean, sweep: boolean?)
	Power.Zones[zone] = on
	local list = {}
	for _, light in Power.Lights do
		if light:GetAttribute("Zone") == zone then
			table.insert(list, light)
		end
	end
	if sweep then
		-- lights come on (or die) one after another, which reads beautifully in corridors
		table.sort(list, function(a, b)
			local pa = a.Parent and a.Parent:IsA("BasePart") and a.Parent.Position or Vector3.zero
			local pb = b.Parent and b.Parent:IsA("BasePart") and b.Parent.Position or Vector3.zero
			return pa.X < pb.X
		end)
		task.spawn(function()
			for _, light in list do
				if Power.Zones[zone] == on then
					setVisual(light, on)
					task.wait(0.06)
				end
			end
		end)
	else
		for _, light in list do
			setVisual(light, on)
		end
	end
end

-- Flickers powered lights within `radius` of `center` (or in `zone`) for `duration` seconds.
function Power.Flicker(center: Vector3?, radius: number?, duration: number, zone: string?)
	local targets = {}
	for _, light in Power.Lights do
		local z = light:GetAttribute("Zone")
		if Power.Zones[z] and not flickering[light] and (zone == nil or z == zone) then
			local parent = light.Parent
			local pos = parent and parent:IsA("BasePart") and parent.Position
			if center == nil or (pos and (pos - center).Magnitude <= (radius or 30)) then
				table.insert(targets, light)
			end
		end
	end
	for _, light in targets do
		flickering[light] = true
	end
	task.spawn(function()
		local t = 0
		while t < duration do
			for _, light in targets do
				if light.Parent then
					setVisual(light, math.random() < 0.45)
				end
			end
			local step = 0.05 + math.random() * 0.12
			task.wait(step)
			t += step
		end
		for _, light in targets do
			flickering[light] = nil
			if light.Parent then
				setVisual(light, Power.Zones[light:GetAttribute("Zone")] == true)
			end
		end
	end)
end

-- Kills all lights in a radius briefly (used when the Shadow passes by).
function Power.Blackout(center: Vector3, radius: number, duration: number)
	local targets = {}
	for _, light in Power.Lights do
		local parent = light.Parent
		if not flickering[light] and parent and parent:IsA("BasePart") and (parent.Position - center).Magnitude <= radius and light.Enabled then
			table.insert(targets, light)
			flickering[light] = true
			setVisual(light, false)
		end
	end
	task.delay(duration, function()
		for _, light in targets do
			flickering[light] = nil
			if light.Parent then
				setVisual(light, Power.Zones[light:GetAttribute("Zone")] == true)
			end
		end
	end)
end

function Power.Emergency(zone: string, on: boolean)
	for _, light in Power.Lights do
		if light:GetAttribute("Zone") == zone then
			light.Color = on and Config.Palette.Emergency or (originalColor[light] or light.Color)
		end
	end
end

function Power.Reset()
	Power.Zones = { Ext = true }
	Power.Lights = {}
	bulbs = {}
	flickering = {}
	originalColor = {}
end

Power.Reset()

return Power
