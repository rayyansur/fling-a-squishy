--!nocheck
-- Offline runner for the pure cloud tests (no Instances, no services beyond module lookups).
--   lune run tests/local/run.luau econ snowcells snowconfig
-- Each named tests/cloud/<name>.test.luau runs with a fake `game` whose services map onto
-- game/src/<Service>/..., so `require(RS.Shared.Util.X)` loads the real source file.
-- Roblox datatypes (CFrame, Vector3, Vector2) come from @lune/roblox. With --place, the built
-- out/Game.rbxlx is loaded too, so ServerStorage / Workspace are the real built instances (run
-- tools/check.sh first). Tests that need players, remotes or running scripts still need Studio / CI.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = "game/src"
local cache = {}
local env -- forward

local Proxy = {}
local function proxy(path: string)
	return setmetatable({ __path = path }, Proxy)
end
Proxy.__index = function(self, k)
	if k == "Parent" then
		return proxy((self.__path:match("^(.*)/[^/]+$")))
	end
	if k == "Name" then
		return self.__path:match("([^/]+)$")
	end
	if k == "WaitForChild" or k == "FindFirstChild" then
		return function(s, name)
			return s[name]
		end
	end
	return proxy(self.__path .. "/" .. k)
end
Proxy.__tostring = function(self)
	return self.__path
end

local function fileOf(path: string): (string?, boolean)
	for _, suffix in { ".luau", ".lua" } do
		if fs.isFile(path .. suffix) then
			return path .. suffix, false
		end
	end
	for _, init in { "/init.luau", "/init.lua" } do
		if fs.isFile(path .. init) then
			return path .. init, true
		end
	end
	return nil, false
end

local function load(path: string, scriptProxy)
	-- a flat table: Luau's import fast-path skips __index on environments
	local e = table.clone(env)
	e.script = scriptProxy
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = e, injectGlobals = true })
	return fn()
end

local function req(target)
	if type(target) == "table" and getmetatable(target) == Proxy then
		local path = target.__path
		if cache[path] == nil then
			local file, isInit = fileOf(path)
			assert(file, "no module at " .. path)
			cache[path] = load(file, target)
		end
		return cache[path]
	end
	return require(target)
end

local services = {
	ReplicatedStorage = proxy(ROOT .. "/ReplicatedStorage"),
	ServerScriptService = proxy(ROOT .. "/ServerScriptService"),
	-- module-level lookups only; nothing is tagged offline
	CollectionService = { GetTagged = function()
		return {}
	end },
}
local args = {}
local place = nil
for _, a in process.args do
	if a == "--place" then
		place = roblox.deserializePlace(fs.readFile("out/Game.rbxlx"))
	else
		table.insert(args, a)
	end
end

local fakeGame = {
	GetService = function(_, name)
		if services[name] then
			return services[name]
		end
		if place then
			return place:GetService(name)
		end
		error("service " .. name .. " is not available offline (try --place)")
	end,
}

-- Lune has no Random: a small LCG with the two methods the game uses
local Random = {
	new = function(seed: number?)
		local r = (seed or 1) % 2147483648
		local function step(): number
			r = (r * 1103515245 + 12345) % 2147483648
			return r
		end
		return {
			NextNumber = function(_, a: number?, b: number?): number
				local x = step() / 2147483648
				return if a and b then a + (b - a) * x else x
			end,
			NextInteger = function(_, a: number, b: number): number
				return a + step() % (b - a + 1)
			end,
		}
	end,
}

env = {
	game = fakeGame,
	require = req,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	Instance = roblox.Instance,
	Random = Random,
	workspace = place and place:GetService("Workspace"),
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
}

local t = {}
local passed, failed = 0, {}
function t.info(msg)
	print("  info: " .. tostring(msg))
end
function t.expect(cond, msg)
	if not cond then
		error(msg or "expectation failed", 2)
	end
	return cond
end
function t.test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed += 1
	else
		table.insert(failed, name .. " :: " .. tostring(err))
	end
end

for _, name in args do
	local path = "tests/cloud/" .. name .. ".test.luau"
	local base = "tests/cloud/" .. name
	if not fs.isFile(path) and fs.isFile("tests/local/" .. name .. ".luau") then
		-- local-only suites (balance sim) live in tests/local
		path, base = "tests/local/" .. name .. ".luau", "tests/local/" .. name
	end
	local ok, err = pcall(function()
		load(path, proxy(base))(t)
	end)
	if not ok then
		table.insert(failed, name .. " (load) :: " .. tostring(err))
	end
end

print(("passed %d, failed %d"):format(passed, #failed))
for _, f in failed do
	print("FAIL " .. f)
end
process.exit(if #failed == 0 then 0 else 1)
