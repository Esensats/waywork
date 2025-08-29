local P = {}

-- Shell-safe quoting: wraps in single quotes, escapes inner quotes
local function shell_quote(str)
	return "'" .. tostring(str):gsub("'", "'\"'\"'") .. "'"
end

-- Build a safe shell command from argv
local function build_cmd(argv)
	local quoted = {}
	for i, arg in ipairs(argv) do
		quoted[i] = shell_quote(arg)
	end
	return table.concat(quoted, " ")
end

--- Check if a process matching the given pattern is running.
--- Uses `pgrep -f -- <pattern>`
--- @param pattern string
function P.is_running(pattern)
	local cmd = build_cmd({ "pgrep", "-f", "--", pattern })
	local h = io.popen(cmd)
	if not h then
		return false
	end
	local r = h:read("*l")
	h:close()
	return r ~= nil
end

--- @class waywall
--- @field exec fun(cmd: string): nil

--- wrapper around waywall.exec
--- @param ww waywall
--- @param argv table array-like table of args
--- @return nil
function P.ww_exec_argv(ww, argv)
	-- No quoting needed; execvp-style expects raw argv
	assert(type(argv) == "table", "argv must be an array-like table of strings")
	for i, v in ipairs(argv) do
		assert(type(v) == "string", "argv element must be a string")
	end
	local cmd = table.concat(argv, " ")
	return ww.exec(cmd)
end

--- Return a function that starts an application when called.
--- @param ww waywall waywall dependency
--- @param app_path string path to the application executable
--- @param args? string[] optional additional arguments to pass to the application
--- @return fun(): nil
function P.start_application(ww, app_path, args)
	return function()
		local argv = { app_path }
		if args then
			for _, a in ipairs(args) do
				argv[#argv + 1] = a
			end
		end
		P.ww_exec_argv(ww, argv)(ww, argv)
	end
end

--- Ensure an application is running, start it if not.
--- @param ww waywall waywall dependency
--- @param app_path string path to the application executable
--- @param args? string[] optional additional arguments to pass to the application
--- @return fun(pattern: string): fun(): nil
function P.ensure_application(ww, app_path, args)
	return function(pattern)
		return function()
			if not P.is_running(pattern) then
				local argv = { app_path }
				if args then
					for _, a in ipairs(args) do
						argv[#argv + 1] = a
					end
				end
				P.ww_exec_argv(ww, argv)
			end
		end
	end
end

--- Ensure a Java JAR is running, start it if not.
--- @param ww waywall
--- @param java_path string path to java executable
--- @param jar_path string path to the JAR file
--- @param args? string[] optional additional arguments to pass to java
--- @return fun(pattern: string): fun(): nil
function P.ensure_java_jar(ww, java_path, jar_path, args)
	return function(pattern)
		return function()
			if not P.is_running(pattern) then
				local argv = { java_path }
				if args then
					for _, a in ipairs(args) do
						argv[#argv + 1] = a
					end
				end
				argv[#argv + 1] = "-jar"
				argv[#argv + 1] = jar_path
				P.ww_exec_argv(ww, argv)
			end
		end
	end
end

return P
