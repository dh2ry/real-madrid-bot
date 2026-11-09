--!nonstrict
-- Minimal pure-Luau signal used for communication between server/client modules.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { fn = fn, connected = true }
	table.insert(self._handlers, handler)
	local handlers = self._handlers
	return {
		Disconnect = function()
			handler.connected = false
			local i = table.find(handlers, handler)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
