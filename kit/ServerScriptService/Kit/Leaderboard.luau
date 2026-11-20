--!strict
-- Leaderboard: all-time top lists on OrderedDataStores (GUIDELINES: retries, budget-friendly
-- writes). A board remembers each player's latest value, writes the changed ones every
-- `refresh` seconds and reads the top `size` back as often, with display names looked up once.
--
--   local Leaderboard = require(ServerScriptService.Kit.Leaderboard)
--   local bowls = Leaderboard.board("Bowls", { size = 10, refresh = 60 })
--   bowls:set(player, data.TotalBowls)       -- whenever it changes (cheap: only remembered)
--   bowls:onUpdate(function(top) ... end)     -- top = { { rank, userId, name, value } }
--   local top = bowls:top()                   -- the last list read
--
-- Values are whole numbers (OrderedDataStores only sort integers) and only ever go up: a lower
-- value than the stored one is ignored, so a reset save can't drag a record down. In Studio
-- (unpublished workbench, API access off) the board keeps this server's values in memory.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboard = {}

export type Entry = { rank: number, userId: number, name: string, value: number }
export type Options = { store: string?, size: number?, refresh: number? }

type BoardImpl = {
	name: string,
	size: number,
	refresh: number,
	ods: OrderedDataStore?,
	pending: { [number]: number },
	known: { [number]: number },
	list: { Entry },
	listeners: { (top: { Entry }) -> () },
	set: (self: BoardImpl, who: Player | number, value: number) -> (),
	top: (self: BoardImpl) -> { Entry },
	onUpdate: (self: BoardImpl, fn: (top: { Entry }) -> ()) -> (),
	flush: (self: BoardImpl) -> (),
	read: (self: BoardImpl) -> (),
}

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and type(n) == "string" then n else ("Chef " .. userId)
	names[userId] = name
	return name
end

-- retry a DataStore call a few times with backoff; nil when it keeps failing
local function try<T>(fn: () -> T): T?
	for attempt = 1, 3 do
		local ok, res = pcall(fn)
		if ok then
			return res
		end
		task.wait(attempt * 2)
	end
	return nil
end

local Board = {}
Board.__index = Board

function Board.set(self: BoardImpl, who: Player | number, value: number)
	local userId = if typeof(who) == "Instance" then (who :: Player).UserId else who :: number
	if userId <= 0 or value ~= value or value == math.huge then
		return
	end
	local v = math.max(0, math.floor(value))
	if v > (self.known[userId] or -1) then
		self.known[userId] = v
		self.pending[userId] = v
	end
end

function Board.top(self: BoardImpl): { Entry }
	return self.list
end

function Board.onUpdate(self: BoardImpl, fn: (top: { Entry }) -> ())
	table.insert(self.listeners, fn)
	if #self.list > 0 then
		task.spawn(fn, self.list)
	end
end

-- write what changed (UpdateAsync keeps the higher of the stored and the new value)
function Board.flush(self: BoardImpl)
	local batch = self.pending
	self.pending = {}
	local ods = self.ods
	if not ods then
		return
	end
	for userId, v in batch do
		try(function()
			return (ods :: any):UpdateAsync(tostring(userId), function(old: any): any
				if type(old) == "number" and old >= v then
					return nil -- keep the record
				end
				return v
			end)
		end)
	end
end

-- read the top back, or rank this server's values when there's no store
function Board.read(self: BoardImpl)
	local rows: { { userId: number, value: number } } = {}
	local ods = self.ods
	if ods then
		local page = try(function()
			return (ods :: any):GetSortedAsync(false, self.size):GetCurrentPage()
		end)
		if not page then
			return -- keep the last list
		end
		for _, item in page :: any do
			local id = tonumber(item.key)
			if id then
				table.insert(rows, { userId = id, value = item.value })
			end
		end
	else
		for id, v in self.known do
			table.insert(rows, { userId = id, value = v })
		end
		table.sort(rows, function(a, b)
			return a.value > b.value
		end)
	end
	local list: { Entry } = {}
	for i = 1, math.min(#rows, self.size) do
		local r = rows[i]
		list[i] = { rank = i, userId = r.userId, name = nameOf(r.userId), value = r.value }
	end
	self.list = list
	for _, fn in self.listeners do
		task.spawn(fn, list)
	end
end

function Leaderboard.board(name: string, opts: Options?): BoardImpl
	local o: Options = opts or {}
	local ok, ods = pcall(function()
		return DataStoreService:GetOrderedDataStore(o.store or ("Leaderboard_" .. name .. "_v1"))
	end)
	local self = setmetatable({
		name = name,
		size = math.clamp(o.size or 10, 1, 100),
		refresh = math.max(30, o.refresh or 60),
		ods = if ok then ods else nil,
		pending = {},
		known = {},
		list = {},
		listeners = {},
	}, Board) :: any
	-- in an unpublished place the store exists but every call errors: probe once
	if self.ods then
		local probe = pcall(function()
			return (self.ods :: any):GetSortedAsync(false, 1)
		end)
		if not probe then
			self.ods = nil
		end
	end
	task.spawn(function()
		task.wait(5)
		while true do
			self:flush()
			self:read()
			task.wait(self.refresh)
		end
	end)
	game:BindToClose(function()
		self:flush()
	end)
	return self
end

return Leaderboard
