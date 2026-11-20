--!nocheck
-- Loads ReplicatedStorage.Shared modules from source inside Lune, so the map is built from the
-- same Config the game runs on (one source of truth for plots, pads and zones).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local ROOT = "game/src/ReplicatedStorage/Shared"
local cache = {}
local Proxy = {}
local load

local function proxy(path)
	return setmetatable({ __path = path }, Proxy)
end
Proxy.__index = function(self, k)
	if k == "Parent" then
		return proxy(self.__path:match("^(.*)/[^/]+$"))
	end
	return proxy(self.__path .. "/" .. k)
end

local function req(target)
	if type(target) == "table" and getmetatable(target) == Proxy then
		return load(target.__path, target)
	end
	return require(target)
end

local env = {
	require = req,
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Enum = roblox.Enum,
}

function load(path, p)
	if cache[path] == nil then
		local file = if fs.isFile(path .. ".luau") then path .. ".luau" else path .. "/init.luau"
		local e = table.clone(env)
		e.script = p or proxy(path)
		cache[path] = luau.load(fs.readFile(file), { debugName = file, environment = e, injectGlobals = true })()
	end
	return cache[path]
end

return function(name)
	return load(ROOT .. "/" .. name)
end
