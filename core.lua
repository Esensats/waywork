local core = {}

--- Create a boolean toggle with on/off callbacks.
function core.toggle(on, off)
	local state = false
	return {
		set = function(v)
			if v == state then
				return state
			end
			state = not not v
			if state then
				on()
			else
				off()
			end
			return state
		end,
		get = function()
			return state
		end,
		toggle = function(self)
			return self.set(not state)
		end,
	}
end

--- Create a resettable timeout using blocking sleep (matches waywall execution model).
--- Calls `f()` only if this invocation is the last one.
function core.resettable_timeout(sleep, f)
	local gen = 0
	return function(delay_ms)
		gen = gen + 1
		local my = gen
		sleep(delay_ms)
		if my == gen then
			f()
		end
	end
end

--- Shallow table copy
function core.copy(t)
	local r = {}
	for k, v in pairs(t) do
		r[k] = v
	end
	return r
end

--- Merge (dst gets missing fields from src)
function core.merge(dst, src)
	for k, v in pairs(src or {}) do
		if dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

return core
