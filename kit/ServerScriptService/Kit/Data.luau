--!strict
-- Data: player saves with session locking (GUIDELINES: retries, session-safe writes, never wipe
-- data on a failed load). Configure with Config.Data (see Kit.Types.DataConfig):
--
--   Config.Data = { store = "PlayerData_v1", defaults = { Coins = 0, Owned = {} },
--                   mirror = { "Coins" }, leaderstats = { "Coins" } }
--
--   Data.onLoaded(function(player, data) ... end)      -- also runs for players already loaded
--   Data.update(player, function(data) data.Coins += 5 end)
--   local data = Data.get(player)                     -- read; change it only through update()
--
-- Each save is { data, receipts, lock = { job, t } }. A server takes the lock on load, refreshes it
-- on every autosave and clears it on leave. Another server only steals a lock older than
-- LOCK_TTL (a crashed server). A load that errors or stays locked kicks the player with a message
-- instead of handing them a blank save, and a server that lost its lock stops writing.
--
-- In Studio, when DataStores can't be reached (unpublished workbench, API access off), saves live
-- in memory for the session.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Kit.Types)
local Config = require(ReplicatedStorage.Shared.Config) :: any

local Data = {}
Data.LOCK_TTL = 300 -- seconds; autosave refreshes the lock well inside this
Data.MAX_RECEIPTS = 100

export type Store = {
	UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any,
}

type Record = {
	data: { [string]: any },
	receipts: { string }?,
	lock: { job: string, t: number }?,
	v: number,
}

export type Session = {
	key: string,
	job: string,
	store: Store,
	data: { [string]: any },
	receipts: { string },
	alive: boolean,
}

------------------------------------------------------------------ helpers (pure)
function Data.copy<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v :: any do
		out[k] = Data.copy(x)
	end
	return (out :: any) :: T
end

-- fill keys that exist in defaults but not in data (new fields added after a player's last save)
function Data.reconcile(data: { [string]: any }, defaults: { [string]: any })
	for k, v in defaults do
		if data[k] == nil then
			data[k] = Data.copy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			Data.reconcile(data[k], v) -- dictionaries only; arrays belong to the player
		end
	end
end

-- An in-memory store with UpdateAsync semantics (Studio fallback, and tests)
function Data.memoryStore(): Store
	local rows: { [string]: any } = {}
	local store = {}
	function store.UpdateAsync(_self: any, key: string, transform: (any) -> any): any
		local new = transform(Data.copy(rows[key]))
		if new ~= nil then
			rows[key] = Data.copy(new)
		end
		return new
	end
	return store
end

------------------------------------------------------------------ sessions (pure over a Store)
-- One attempt. Returns the session, or nil + "locked" | error message.
function Data.open(store: Store, key: string, defaults: { [string]: any }, job: string, now: number?): (Session?, string?)
	local t = now or os.time()
	local outcome: string? = nil
	local ok, res = pcall(function()
		return store:UpdateAsync(key, function(old: any): any
			outcome = nil
			if old ~= nil and (type(old) ~= "table" or type(old.data) ~= "table") then
				outcome = "save is not in the kit's format"
				return nil
			end
			local rec = old :: Record?
			if rec and rec.lock and rec.lock.job ~= job and t - rec.lock.t < Data.LOCK_TTL then
				outcome = "locked"
				return nil
			end
			local record: Record = rec or { data = Data.copy(defaults), receipts = {}, v = 1 }
			record.lock = { job = job, t = t }
			return record
		end)
	end)
	if not ok then
		return nil, tostring(res)
	end
	if outcome then
		return nil, outcome
	end
	local record = res :: Record
	local data = record.data
	Data.reconcile(data, defaults)
	return {
		key = key,
		job = job,
		store = store,
		data = data,
		receipts = record.receipts or {},
		alive = true,
	}, nil
end

-- Write the session back. release = clear the lock (player left / server closing).
-- Returns true, or false + "lost" (another server owns the save now) | error message.
function Data.save(session: Session, release: boolean, now: number?): (boolean, string?)
	if not session.alive then
		return false, "lost"
	end
	local t = now or os.time()
	local lost = false
	local ok, err = pcall(function()
		session.store:UpdateAsync(session.key, function(old: any): any
			lost = false
			local rec = old :: Record?
			if not rec or not rec.lock or rec.lock.job ~= session.job then
				lost = true
				return nil
			end
			rec.data = session.data
			while #session.receipts > Data.MAX_RECEIPTS do
				table.remove(session.receipts, 1)
			end
			rec.receipts = session.receipts
			rec.lock = if release then nil else { job = session.job, t = t }
			return rec
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if lost then
		session.alive = false
		return false, "lost"
	end
	if release then
		session.alive = false
	end
	return true, nil
end

------------------------------------------------------------------ players
local cfg: Types.DataConfig = Config.Data or {}
local defaults: { [string]: any } = cfg.defaults or {}
local sessions: { [Player]: Session } = {}
local loadedEvent = Instance.new("BindableEvent")
local changedEvent = Instance.new("BindableEvent")
local store: Store? = nil
local started = false
local closing = false

Data.changed = changedEvent.Event -- (player, data) after every update()

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function mirror(player: Player, data: { [string]: any })
	local mirrored: { string } = cfg.mirror or {}
	for _, k in mirrored do
		local v = data[k]
		local t = type(v)
		if t == "number" or t == "string" or t == "boolean" then
			player:SetAttribute(k, v)
		end
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local shown: { string } = cfg.leaderstats or {}
		for _, k in shown do
			local value = stats:FindFirstChild(k)
			if value and value:IsA("NumberValue") and type(data[k]) == "number" then
				value.Value = data[k]
			end
		end
	end
end

local function makeLeaderstats(player: Player)
	if not cfg.leaderstats or #cfg.leaderstats == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, k in cfg.leaderstats do
		local v = Instance.new("NumberValue")
		v.Name = k
		v.Parent = folder
	end
	folder.Parent = player
end

local function load(player: Player)
	assert(store, "Data.start() first")
	local key = "u_" .. player.UserId
	local session: Session?, err: string? = nil, nil
	local deadline = os.clock() + 60
	local attempt = 0
	while os.clock() < deadline and player.Parent do
		attempt += 1
		session, err = Data.open(store, key, defaults, jobId())
		if session then
			break
		end
		-- locked: the previous server is usually still saving; errors: back off
		task.wait(if err == "locked" then 5 else math.min(2 ^ attempt, 15))
	end
	if not session then
		print(("[Kit.Data] could not load %s (%s); kicking instead of using a blank save"):format(player.Name, tostring(err)))
		if player.Parent then
			player:Kick("We couldn't load your save right now, so nothing was lost. Please rejoin in a minute.")
		end
		return
	end
	if not player.Parent then
		Data.save(session, true)
		return
	end
	sessions[player] = session
	makeLeaderstats(player)
	mirror(player, session.data)
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, session.data)
end

local function saveWithRetry(player: Player, session: Session, release: boolean): boolean
	for attempt = 1, 4 do
		local ok, err = Data.save(session, release)
		if ok then
			return true
		end
		if err == "lost" then
			print(("[Kit.Data] %s's save is open on another server; this server stopped writing it"):format(player.Name))
			if player.Parent and not release then
				player:Kick("Your save was opened on another server. Please rejoin.")
			end
			return false
		end
		if attempt < 4 then
			task.wait(attempt * 2)
		end
	end
	return false
end

local function release(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	saveWithRetry(player, session, true)
	sessions[player] = nil
end

function Data.start()
	if started then
		return
	end
	started = true
	local ok, real = pcall(function()
		return DataStoreService:GetDataStore(cfg.store or "PlayerData_v1")
	end)
	if ok and RunService:IsStudio() then
		ok = pcall(function()
			(real :: DataStore):GetAsync("__kit_probe")
		end)
	end
	if ok then
		store = (real :: any) :: Store
	elseif RunService:IsStudio() then
		print("[Kit.Data] DataStores unavailable in this Studio place: saves are kept in memory")
		store = Data.memoryStore()
	else
		error("[Kit.Data] DataStoreService unavailable: " .. tostring(real))
	end

	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(release)
	game:BindToClose(function()
		closing = true
		local pending = 0
		for p in sessions do
			pending += 1
			task.spawn(function()
				release(p)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while not closing do
			task.wait(cfg.autosaveSeconds or 60)
			for p, s in sessions do
				if s.alive and not closing then
					task.spawn(saveWithRetry, p, s, false)
				end
			end
		end
	end)
end

function Data.get(player: Player): { [string]: any }?
	local s = sessions[player]
	return s and s.data
end

-- waits for the player's save to load (nil if they leave or it doesn't load in time)
function Data.waitFor(player: Player, timeout: number?): { [string]: any }?
	local deadline = os.clock() + (timeout or 30)
	while not sessions[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return Data.get(player)
end

function Data.update(player: Player, fn: ({ [string]: any }) -> ()): boolean
	local s = sessions[player]
	if not s or not s.alive then
		return false
	end
	fn(s.data)
	mirror(player, s.data)
	changedEvent:Fire(player, s.data)
	return true
end

function Data.saveNow(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and s.alive and saveWithRetry(player, s, false)
end

function Data.onLoaded(fn: (Player, { [string]: any }) -> ())
	loadedEvent.Event:Connect(fn)
	for p, s in sessions do
		task.spawn(fn, p, s.data)
	end
end

-- Kit.Shop: purchase ids already granted, saved with the player's data
function Data.session(player: Player): Session?
	return sessions[player]
end

return Data
