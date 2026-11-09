-- Builds the DataModel tree of script instances and an instance-based `require`.
local scriptByKey = {}
local cache = {}
for key, cls in CLASSES do
	local parts = string.split(key, "/")
	local parent = game:GetService(parts[1])
	for i = 2, #parts - 1 do
		local child = parent:FindFirstChild(parts[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = parts[i]
			child.Parent = parent
		end
		parent = child
	end
	local inst = Instance.new(cls)
	inst.Name = parts[#parts]
	inst.Parent = parent
	rawset(inst, "_sourceKey", key)
	scriptByKey[key] = inst
end

function require(target)
	local key = rawget(target, "_sourceKey")
	assert(key, "require of non-module " .. tostring(target))
	local entry = cache[key]
	if entry == nil then
		cache[key] = { loading = true }
		local value = SOURCES[key](target)
		cache[key] = { value = value }
		return value
	end
	assert(not entry.loading, "cyclic require: " .. key)
	return entry.value
end

local function runScript(key)
	task.spawn(SOURCES[key], scriptByKey[key])
end
