--!nonstrict
-- Crash-test harness. tools/roblox_cloud.py runs this INSIDE a real Roblox server
-- (Open Cloud Luau Execution) against the freshly published test place.
--
-- Generic checks, for any game:
--   1. every ModuleScript requires without erroring
--   2. every server Script's start() modules boot (see GUIDELINES: logic lives in modules)
--   3. nothing logs an error for a few seconds afterwards
-- Then every tests/cloud/*.test.luau file runs (inlined below by the runner).
--
-- Returns { passed, failed = {...}, errors = {...}, info = {...} }.

local LogService = game:GetService("LogService")
local ServerScriptService = game:GetService("ServerScriptService")

local results = { passed = 0, failed = {}, errors = {}, info = {} }

LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError then
		table.insert(results.errors, msg)
	end
end)

local t = {}
-- filled in by tools/roblox_cloud.py test (e.g. expectProductIds)
t.options = {} --@@OPTIONS@@

function t.info(msg)
	table.insert(results.info, tostring(msg))
end

function t.test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		results.passed += 1
	else
		table.insert(results.failed, name .. " :: " .. tostring(err))
	end
end

function t.expect(cond, msg)
	if not cond then
		error(msg or "expectation failed", 2)
	end
	return cond
end

function t.waitFor(fn, timeout)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local v = fn()
		if v then
			return v
		end
		task.wait(0.1)
	end
	return nil
end

-- Run fn on its own thread; fail if it errors or is still yielding after `seconds`
-- (an infinite WaitForChild would otherwise hang the whole test until the task times out).
function t.within(seconds, fn)
	local done, err = false, nil
	task.spawn(function()
		local ok, e = xpcall(fn, debug.traceback)
		if not ok then
			err = e
		end
		done = true
	end)
	local deadline = os.clock() + seconds
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	if err then
		error(err, 0)
	end
	if not done then
		error(("still yielding after %ds (infinite wait?)"):format(seconds), 0)
	end
end

------------------------------------------------------------------ 1. game modules load
-- Server-side containers only: client modules (StarterPlayerScripts, StarterGui, ...) can't
-- run on a server, and Roblox's own PlayerModule lives there too.
local SERVER_SIDE = { "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "Workspace" }
local modules = {}
for _, svcName in SERVER_SIDE do
	for _, m in game:GetService(svcName):GetDescendants() do
		if m:IsA("ModuleScript") then
			table.insert(modules, m)
		end
	end
end
for _, m in modules do
	t.test("require " .. m:GetFullName(), function()
		t.within(5, function()
			require(m)
		end)
	end)
end
t.info(#modules .. " modules")

------------------------------------------------------------------ 2. boot server modules
-- Place Scripts don't run in this script-execution server, so this pass is what boots the game:
-- logic in a Script's own body never runs here. Modules already marked "Started" are skipped,
-- so nothing connects its handlers twice.
local booted, running = 0, 0
for _, s in ServerScriptService:GetDescendants() do
	if s:IsA("Script") and s.Enabled ~= false then
		for _, child in s:GetChildren() do
			if child:IsA("ModuleScript") and child:GetAttribute("Started") then
				running += 1
			elseif child:IsA("ModuleScript") then
				t.test("start " .. child:GetFullName(), function()
					t.within(10, function()
						local mod = require(child)
						if type(mod) == "table" and type(mod.start) == "function" then
							mod.start()
							booted += 1
						end
					end)
				end)
			end
		end
	end
end
t.info(("%d server modules already running, %d started by the harness"):format(running, booted))

------------------------------------------------------------------ 3. game tests
local GAME_TESTS = {} --@@GAME_TESTS@@
for name, run in GAME_TESTS do
	t.test("suite " .. name, function()
		t.within(60, function()
			run(t)
		end)
	end)
end

task.wait(3)
t.info(("%d passed, %d failed, %d errors logged"):format(results.passed, #results.failed, #results.errors))
return results
