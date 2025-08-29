local core = require("waywork.core")

--- SceneManager manages images, mirrors, and text objects uniformly.
local SceneManager = {}
SceneManager.__index = SceneManager

function SceneManager.new(waywall)
	return setmetatable({ ww = waywall, defs = {}, instances = {}, groups = {} }, SceneManager)
end

--- A scene object definition.
--- @class SceneDef
--- @field kind "mirror" | "image" | "text"
--- @field options table
--- @field path? string (for images)
--- @field text? string (for text)
--- @field groups string[]
--- @field enabled_by_default? boolean

--- Register a scene object by name.
--- @param name string
--- @param def SceneDef
function SceneManager:register(name, def)
	self.defs[name] = core.copy(def)
	if def.groups then
		for _, g in ipairs(def.groups) do
			self.groups[g] = self.groups[g] or {}
			table.insert(self.groups[g], name)
		end
	end
	if def.enabled_by_default then
		self:enable(name, true)
	end
end

function SceneManager:_create(def)
	if def.kind == "mirror" then
		return self.ww.mirror(def.options)
	elseif def.kind == "image" then
		return self.ww.image(def.path, def.options)
	elseif def.kind == "text" then
		return self.ww.text(def.text, def.options)
	end
end

function SceneManager:_ensure(name, enable)
	local inst = self.instances[name]
	if enable and not inst then
		inst = self:_create(self.defs[name])
		self.instances[name] = inst
	elseif not enable and inst then
		inst:close()
		self.instances[name] = nil
	end
end

--- Enable or disable a registered scene object by name.
--- @param name string
--- @param on boolean
function SceneManager:enable(name, on)
	if not self.defs[name] then
		return
	end
	self:_ensure(name, on)
end

--- Disable a registered scene object by name.
--- @param name string
function SceneManager:disable(name)
	self:enable(name, false)
end

--- Enable or disable all scene objects in a group.
--- @param group string
--- @param on boolean
function SceneManager:enable_group(group, on)
	for _, name in ipairs(self.groups[group] or {}) do
		self:enable(name, on)
	end
end

--- Apply a predicate function to all registered scene objects.
---
--- Example:
--- ```lua
--- scene:apply(function(name, def)
---   return def.kind == "mirror" -- enable all mirrors
--- end)
--- ```
--- @param predicate fun(name: string, def: table): boolean
function SceneManager:apply(predicate)
	for name, def in pairs(self.defs) do
		self:enable(name, predicate(name, def))
	end
end

--- Update the destination rectangle of a registered scene object.
--- @param name string
--- @param new_dst table { x=number, y=number, w=number, h=number }
SceneManager.update_dst = function(self, name, new_dst)
	local def = self.defs[name]
	if not def then
		return
	end
	if def.options then
		def.options.dst = core.copy(new_dst)
	end
	local inst = self.instances[name]
	if inst then
		inst:close()
		self.instances[name] = self:_create(def)
	end
end

return { SceneManager = SceneManager }
