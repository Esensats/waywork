local P = {}

local function is_running(pattern)
	local h = io.popen("pgrep -f '" .. pattern .. "'")
	if not h then
		return false
	end
	local r = h:read("*l")
	h:close()
	return r ~= nil
end

function P.ensure_java_jar(ww, java_path, jar_path, args)
	return function(pattern)
		return function()
			if not is_running(pattern) then
				ww.exec(table.concat({ java_path, "-jar", jar_path, args or "" }, " "))
			end
		end
	end
end

return P
