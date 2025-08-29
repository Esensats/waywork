local modes = {}

--- ModeManager orchestrates resolution toggles and on_enter/on_exit hooks.
local ModeManager = {}
ModeManager.__index = ModeManager

function ModeManager.new(waywall)
	return setmetatable({ ww = waywall, active = nil, defs = {} }, ModeManager)
end

--- def: { width, height, on_enter=function(), on_exit=function(), toggle_guard=function()->bool }
function ModeManager:define(name, def)
	self.defs[name] = def
end

local function active_res(ww)
	local w, h = ww.active_res()
	return tonumber(w), tonumber(h)
end

--- Get the mode definition by name, erroring if not found.
--- @param name string
function ModeManager:_get_def(name)
	assert(self.defs[name], "No such mode: " .. tostring(name))
	return self.defs[name]
end

--- Transition to a mode by name, turning off any previously active mode.
--- If name is nil, turn off any active mode.
--- This does not check toggle_guard.
--- @param name string?
function ModeManager:_transition_to(name)
	local function exit_active()
		if self.active then
			local prev = self:_get_def(self.active)
			self.ww.set_resolution(0, 0)
			if prev.on_exit then
				prev.on_exit()
			end
			self.active = nil
		end
	end

	local function enter_mode(_name)
		if _name then
			local new = self:_get_def(_name)
			self.ww.set_resolution(new.width, new.height)
			if new.on_enter then
				new.on_enter()
			end
			self.active = _name
		end
	end

	if name == nil then
		exit_active()
		return
	end
	if name == self.active then
		-- already active, do nothing
		return
	end
	exit_active()
	enter_mode(name)
end

--- Toggle a mode by name. If it's active, turn it off. If it's inactive, turn it on.
--- If the mode has a toggle_guard and it returns false, do nothing and return false.
--- @param name string
--- @return boolean|nil
function ModeManager:toggle(name)
	local ww, def = self.ww, self.defs[name]
	if not def then
		return
	end
	if def.toggle_guard and def.toggle_guard() == false then
		return false
	end
	-- local w, h = active_res(ww)
	-- if w == def.width and h == def.height then
	-- 	ww.set_resolution(0, 0)
	-- 	if def.on_exit then
	-- 		def.on_exit()
	-- 	end
	-- 	self.active = nil
	-- else
	-- 	ww.set_resolution(def.width, def.height)
	-- 	if def.on_enter then
	-- 		def.on_enter()
	-- 	end
	-- 	-- exit previous if different
	-- 	self.active = name
	-- end

	if name == self.active then
		self:_transition_to(nil)
	else
		self:_transition_to(name)
	end
end

modes.ModeManager = ModeManager
return modes
