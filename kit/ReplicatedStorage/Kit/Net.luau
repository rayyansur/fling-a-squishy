--!strict
-- Net: remotes with argument validation and per-player rate limits (GUIDELINES: validate every
-- remote's arguments and rate-limit them). Remotes live in ReplicatedStorage.Kit.Remotes and are
-- created by the server the first time a name is used.
--
-- server:  Net.on("Plant", { args = { "string", "int" }, rate = 4 }, function(player, seed, slot) end)
--          Net.handle("GetStats", { rate = 1 }, function(player) return stats end)   -- RemoteFunction
--          Net.fire(player, "Toast", "Saved!")   Net.fireAll("RoundStart", 30)
-- client:  Net.send("Plant", "carrot", 3)   local s = Net.call("GetStats")   Net.listen("Toast", fn)
--
-- Arg types are typeof() names plus "int" (whole number). Numbers must be finite, strings at most
-- spec.maxString (default 100) long. Bad or too-frequent calls are dropped silently and counted in
-- Net.dropped.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)

local Net = {}
Net.dropped = 0

local IS_SERVER = RunService:IsServer()
local FOLDER = "Remotes"

local function folder(): Folder
	local kit = script.Parent
	if IS_SERVER then
		local f = kit:FindFirstChild(FOLDER)
		if not f then
			f = Instance.new("Folder")
			f.Name = FOLDER
			f.Parent = kit
		end
		return f :: Folder
	end
	return kit:WaitForChild(FOLDER) :: Folder
end

local function remote(name: string, class: "RemoteEvent" | "RemoteFunction"): Instance
	local f = folder()
	local r = f:FindFirstChild(name)
	if r then
		assert(r.ClassName == class, ("Net: %s is a %s, not a %s"):format(name, r.ClassName, class))
		return r
	end
	if IS_SERVER then
		local inst = Instance.new(class)
		inst.Name = name
		inst.Parent = f
		return inst
	end
	local inst = f:WaitForChild(name, 15)
	assert(inst, "Net: server never created remote " .. name)
	return inst
end

------------------------------------------------------------------ validation (pure)
local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- returns true, or false + reason
function Net.check(spec: Types.NetSpec, args: { any }, n: number): (boolean, string?)
	local want: { string } = spec.args or {}
	if n > #want then
		return false, ("%d args, expected at most %d"):format(n, #want)
	end
	local maxString = spec.maxString or 100
	for i, kind in want do
		local v = args[i]
		local t = typeof(v)
		if kind == "int" then
			if t ~= "number" or not isFinite(v) or v ~= math.floor(v) then
				return false, ("arg %d: expected int"):format(i)
			end
		elseif kind == "number" then
			if t ~= "number" or not isFinite(v) then
				return false, ("arg %d: expected finite number"):format(i)
			end
		elseif t ~= kind then
			return false, ("arg %d: expected %s, got %s"):format(i, kind, t)
		elseif kind == "string" and #v > maxString then
			return false, ("arg %d: string longer than %d"):format(i, maxString)
		elseif kind == "Vector3" and not (isFinite(v.X) and isFinite(v.Y) and isFinite(v.Z)) then
			return false, ("arg %d: non-finite Vector3"):format(i)
		end
	end
	return true
end

-- token bucket: limiter(now) -> allowed
function Net.limiter(rate: number, burst: number): (now: number) -> boolean
	local tokens, last = burst, -math.huge
	return function(now: number): boolean
		if last > -math.huge then
			tokens = math.min(burst, tokens + (now - last) * rate)
		end
		last = now
		if tokens >= 1 then
			tokens -= 1
			return true
		end
		return false
	end
end

------------------------------------------------------------------ server
local buckets: { [Player]: { [string]: (number) -> boolean } } = {}
if IS_SERVER then
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

local function admit(player: Player, name: string, spec: Types.NetSpec, args: { any }, n: number): boolean
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local lim = mine[name]
	if not lim then
		local rate = spec.rate or 5
		lim = Net.limiter(rate, spec.burst or math.max(1, math.ceil(rate * 2)))
		mine[name] = lim
	end
	if not lim(os.clock()) or not Net.check(spec, args, n) then
		Net.dropped += 1
		return false
	end
	return true
end

function Net.on(name: string, spec: Types.NetSpec, handler: (Player, ...any) -> ())
	assert(IS_SERVER, "Net.on is server-only")
	local ev = remote(name, "RemoteEvent") :: RemoteEvent
	ev.OnServerEvent:Connect(function(player, ...)
		local args, n = { ... }, select("#", ...)
		if admit(player, name, spec, args, n) then
			handler(player, table.unpack(args, 1, n))
		end
	end)
end

function Net.handle(name: string, spec: Types.NetSpec, handler: (Player, ...any) -> ...any)
	assert(IS_SERVER, "Net.handle is server-only")
	local fn = remote(name, "RemoteFunction") :: RemoteFunction
	fn.OnServerInvoke = function(player, ...)
		local args, n = { ... }, select("#", ...)
		if admit(player, name, spec, args, n) then
			return handler(player, table.unpack(args, 1, n))
		end
		return nil
	end
end

function Net.fire(player: Player, name: string, ...: any)
	assert(IS_SERVER, "Net.fire is server-only");
	(remote(name, "RemoteEvent") :: RemoteEvent):FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	assert(IS_SERVER, "Net.fireAll is server-only");
	(remote(name, "RemoteEvent") :: RemoteEvent):FireAllClients(...)
end

------------------------------------------------------------------ client
function Net.send(name: string, ...: any)
	assert(not IS_SERVER, "Net.send is client-only");
	(remote(name, "RemoteEvent") :: RemoteEvent):FireServer(...)
end

function Net.call(name: string, ...: any): ...any
	assert(not IS_SERVER, "Net.call is client-only")
	return (remote(name, "RemoteFunction") :: RemoteFunction):InvokeServer(...)
end

function Net.listen(name: string, fn: (...any) -> ()): RBXScriptConnection
	assert(not IS_SERVER, "Net.listen is client-only")
	return (remote(name, "RemoteEvent") :: RemoteEvent).OnClientEvent:Connect(fn)
end

-- server: make sure remotes exist before clients wait for them (call from start())
function Net.declare(names: { string })
	assert(IS_SERVER, "Net.declare is server-only")
	for _, n in names do
		remote(n, "RemoteEvent")
	end
end

return Net
