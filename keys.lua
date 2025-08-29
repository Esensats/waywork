local K = {}

--- Build actions table from simple mapping { [key] = fn, ... }
function K.actions(map)
	local t = {}
	for k, fn in pairs(map) do
		t[k] = fn
	end
	return t
end

return K
