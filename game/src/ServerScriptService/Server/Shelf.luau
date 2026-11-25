--!strict
-- The shelf (DESIGN 4.4-4.6): arrivals, auto-merge, manual merge, release, the Shelf Full choice,
-- and SQUEEZE. The save holds the shelf; squeeze cooldowns live in State (not saved).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local L = require(ReplicatedStorage.Shared.Util.ShelfLogic)
local Mod = require(ReplicatedStorage.Shared.Util.Modifier)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local State = require(script.Parent.State)
local Plots = require(script.Parent.Plots)
local Economy = require(script.Parent.Economy)
local Tutorial = require(script.Parent.Tutorial)
local Analytics = require(script.Parent.Analytics)
local Progress = require(script.Parent.Progress)

local S, G, E = Config.Squishies, Config.Game, Config.Economy
local RARITY_INDEX = {}
for i, r in Config.Zones.Rarities do
	RARITY_INDEX[r] = i
end

local Shelf = {}

local function newUid(player: Player): () -> string
	return function(): string
		local id = ""
		Data.update(player, function(d)
			d.uidSeq += 1
			id = tostring(d.uidSeq)
		end)
		return id
	end
end

-- ids allocated inside an existing Data.update callback (no nested update)
local function uidFrom(d: any): () -> string
	return function(): string
		d.uidSeq += 1
		return tostring(d.uidSeq)
	end
end

-- merges consume squishies: forget their squeeze timers and carry the latest one onto the
-- merged result, so merging never skips the squeeze cooldown
local function carryReady(player: Player, before: { string }, after: { any }, made: { any })
	local st = State.get(player)
	local still: { [string]: boolean } = {}
	for _, e in after do
		still[e.uid] = true
	end
	local latest = 0
	for _, uid in before do
		if not still[uid] then
			latest = math.max(latest, st.readyAt[uid] or 0)
			st.readyAt[uid] = nil
		end
	end
	for _, m in made do
		if still[m.uid] then
			st.readyAt[m.uid] = latest
		end
	end
end

local function uidsOf(shelf: { any }): { string }
	local out = {}
	for _, e in shelf do
		table.insert(out, e.uid)
	end
	return out
end

local drainQueue: (Player) -> boolean

-- full shelf for the owner, with squeeze readiness (server time)
function Shelf.send(player: Player)
	-- space may have freed up (release, merge, slot purchase): shelve waiting arrivals first
	drainQueue(player)
	local data = Data.get(player)
	if not data then
		return
	end
	local ready = State.get(player).readyAt
	local out = table.create(#data.shelf)
	for _, e in data.shelf do
		table.insert(out, { uid = e.uid, s = e.s, size = e.z, glitter = e.g, mod = e.m, readyAt = ready[e.uid] or 0 })
	end
	Net.fire(player, "ShelfUpdate", out)
	Plots.publishShelf(player)
	Economy.refresh(player)
end

local function recordDex(d: any, s: string, z: number, g: boolean, m: string?): boolean
	local entry = d.dex[s]
	local isNew = entry == nil
	if not entry then
		entry = { n = 0, best = 1, glitter = false }
		d.dex[s] = entry
	end
	entry.best = math.max(entry.best, z)
	entry.glitter = entry.glitter or g
	if m then
		entry.mods = entry.mods or {}
		entry.mods[m] = true
	end
	return isNew
end

local function announceMerge(player: Player, m: any)
	local sp = S.ById[m.s]
	Net.fire(player, "Merged", m.uid, m.s, m.z, m.g, m.m or "")
	Tutorial.onMerge(player)
	Progress.emit(player, "merge", m.z)
	Analytics.custom(player, "MergeSize", m.z)
	if m.z == 3 and sp and RARITY_INDEX[sp.rarity] >= 5 then
		Net.fireAll("Announce", ("⭐ %s merged a MEGA %s!"):format(player.DisplayName, sp.name), sp.rarity)
	end
end

local function doAutoMerge(player: Player, s: string, z: number, g: boolean, mod: string?)
	local merged: { any } = {}
	local before: { string } = {}
	Data.update(player, function(d)
		before = uidsOf(d.shelf)
		merged = L.autoMerge(d.shelf, s, z, g, uidFrom(d), mod)
		d.stats.merges += #merged
		for _, m in merged do
			recordDex(d, m.s, m.z, m.g, m.m)
		end
	end)
	local data = Data.get(player)
	if data and #merged > 0 then
		carryReady(player, before, data.shelf, merged)
	end
	for _, m in merged do
		announceMerge(player, m)
	end
end

local function insert(player: Player, entry: any)
	Data.update(player, function(d)
		table.insert(d.shelf, entry)
	end)
	State.get(player).readyAt[entry.uid] = 0
	local data = Data.get(player)
	if data and data.autoMerge then
		doAutoMerge(player, entry.s, 1, entry.g, entry.m)
	end
end

local function lowestIndex(player: Player, data: any): number?
	return L.lowest(data.shelf, function(e)
		return Economy.incomeOf(player, data, e)
	end)
end

local function showNextFull(player: Player)
	local st = State.get(player)
	local p = st.fullQueue[1]
	local data = Data.get(player)
	if not p or not data then
		return
	end
	local low = lowestIndex(player, data)
	local lowEntry = low and data.shelf[low]
	p.deadline = os.clock() + G.ShelfFullAutoSeconds
	Net.fire(player, "ShelfFull", { uid = p.entry.uid, s = p.entry.s, size = 1, glitter = p.entry.g, mod = p.entry.m }, lowEntry and { uid = lowEntry.uid, s = lowEntry.s, size = lowEntry.z, glitter = lowEntry.g, mod = lowEntry.m }, G.ShelfFullAutoSeconds)
	local mine = p
	task.delay(G.ShelfFullAutoSeconds + 0.25, function()
		if st.fullQueue[1] == mine then
			-- auto-choice: keep the higher income
			local d = Data.get(player)
			if not d then
				return
			end
			local li = lowestIndex(player, d)
			local newIncome = Economy.incomeOf(player, d, mine.entry)
			local lowIncome = if li then Economy.incomeOf(player, d, d.shelf[li]) else math.huge
			Shelf.resolveFull(player, newIncome > lowIncome)
		end
	end)
end

-- queued arrivals that fit now (a slot bought, a release, a merge) go straight on the shelf.
-- Returns true if the front of the queue changed.
function drainQueue(player: Player): boolean
	local st = State.get(player)
	local changed = false
	while st.fullQueue[1] do
		local data = Data.get(player)
		local e = st.fullQueue[1].entry
		if not data or not L.fits(data.shelf, E.slotCount(data.slotUpgrades), e.s, e.g, data.autoMerge, e.m) then
			break
		end
		table.remove(st.fullQueue, 1)
		insert(player, e)
		changed = true
	end
	if changed then
		if st.fullQueue[1] then
			showNextFull(player)
		else
			Net.fire(player, "ShelfFull", nil, nil, 0) -- closes the prompt
		end
	end
	return changed
end

-- keepNew: release the lowest-income squishy and shelve the new one; else release the new one.
-- uid (from the client) must name the prompt being answered.
function Shelf.resolveFull(player: Player, keepNew: boolean, uid: string?)
	local st = State.get(player)
	local front = st.fullQueue[1]
	if not front or (uid ~= nil and front.entry.uid ~= uid) then
		return
	end
	if drainQueue(player) then
		Shelf.send(player)
		return
	end
	local p = table.remove(st.fullQueue, 1)
	local data = Data.get(player)
	if not p or not data then
		return
	end
	if keepNew then
		local li = lowestIndex(player, data)
		if li then
			local old = data.shelf[li]
			local pay = Economy.incomeOf(player, data, old) * G.ReleaseSeconds
			Data.update(player, function(d)
				table.remove(d.shelf, li)
			end)
			st.readyAt[old.uid] = nil
			Economy.add(player, pay, "Release")
		end
		insert(player, p.entry)
	else
		local pay = Economy.incomeOf(player, data, p.entry) * G.ReleaseSeconds
		Economy.add(player, pay, "Release")
	end
	Shelf.send(player)
	showNextFull(player)
end

-- a squishy reached the shelf (called by Fling at arriveAt); m = modifier id or nil
function Shelf.arrive(player: Player, s: string, g: boolean, m: string?)
	local data = Data.get(player)
	if not data or not player.Parent then
		return
	end
	local isNew = false
	Data.update(player, function(d)
		isNew = recordDex(d, s, 1, g, m)
		d.dex[s].n += 1
		d.stats.caught += 1
	end)
	local caught = 0
	for _ in data.dex do
		caught += 1
	end
	Progress.emit(player, "dex", caught)
	local entry = { uid = newUid(player)(), s = s, z = 1, g = g, m = m }
	local slots = E.slotCount(data.slotUpgrades)
	Tutorial.onArrive(player)
	Net.fire(player, "Arrived", entry.uid, s, g, isNew, m or "")
	if L.fits(data.shelf, slots, s, g, data.autoMerge, m) then
		insert(player, entry)
	else
		local st = State.get(player)
		table.insert(st.fullQueue, { entry = entry, deadline = 0 })
		if #st.fullQueue == 1 then
			showNextFull(player)
		end
	end
	Shelf.send(player)
end

-- grant a squishy straight onto the shelf (daily rewards); same path as an arrival
function Shelf.grant(player: Player, s: string, g: boolean, m: string?)
	Shelf.arrive(player, s, g, Mod.clean(Config.Zones, m))
end

function Shelf.squeeze(player: Player): (number, number)
	local data = Data.get(player)
	if not data then
		return 0, 0
	end
	local st = State.get(player)
	local now = workspace:GetServerTimeNow()
	local total, count = 0, 0
	local uids = {}
	for _, e in data.shelf do
		if (st.readyAt[e.uid] or 0) <= now then
			total += Economy.incomeOf(player, data, e) * G.SqueezeSeconds
			count += 1
			st.readyAt[e.uid] = now + G.SqueezeCooldown
			table.insert(uids, e.uid)
		end
	end
	if count == 0 then
		return 0, 0
	end
	Economy.add(player, total, "Squeeze")
	Data.update(player, function(d)
		d.stats.squeezes += 1
	end)
	Tutorial.onSqueeze(player)
	Progress.emit(player, "squeeze", 1)
	Net.fire(player, "Squeezed", uids, total, now + G.SqueezeCooldown)
	Shelf.send(player)
	return total, count
end

function Shelf.start()
	Net.declare({ "ShelfUpdate", "ShelfFull", "Squeezed", "Merged", "Arrived", "Announce", "DexState" })

	-- the Squishydex panel asks when it opens: { [speciesId] = { n, best, glitter } }
	Net.on("DexRequest", { rate = 2, burst = 4 }, function(player)
		local data = Data.get(player)
		if data then
			Net.fire(player, "DexState", data.dex)
		end
	end)

	Net.on("SqueezeRequest", { rate = G.SqueezeRate, burst = G.SqueezeRate }, function(player)
		Shelf.squeeze(player)
	end)

	Net.on("ShelfFullChoice", { args = { "boolean", "string" }, rate = 4, maxString = 16 }, function(player, keepNew, uid)
		Shelf.resolveFull(player, keepNew, uid)
	end)

	Net.on("MergeRequest", { args = { "string", "int", "boolean", "string" }, rate = 6, maxString = 24 }, function(player, s, z, g, modStr)
		local mod = Mod.clean(Config.Zones, modStr)
		local data = Data.get(player)
		if not data or not S.ById[s] or z < 1 or z >= L.MAX_SIZE or not L.canMerge(data.shelf, s, z, g, mod) then
			return
		end
		local m
		local before: { string } = {}
		Data.update(player, function(d)
			before = uidsOf(d.shelf)
			m = L.merge(d.shelf, s, z, g, uidFrom(d), mod)
			if m then
				d.stats.merges += 1
				recordDex(d, m.s, m.z, m.g, m.m)
			end
		end)
		if m then
			local after = Data.get(player)
			if after then
				carryReady(player, before, after.shelf, { m })
			end
			announceMerge(player, m)
			Shelf.send(player)
		end
	end)

	Net.on("ReleaseSquishy", { args = { "string" }, rate = 6, maxString = 16 }, function(player, uid)
		local data = Data.get(player)
		local i = data and L.find(data.shelf, uid)
		if not data or not i then
			return
		end
		local pay = Economy.incomeOf(player, data, data.shelf[i]) * G.ReleaseSeconds
		Data.update(player, function(d)
			table.remove(d.shelf, i)
		end)
		State.get(player).readyAt[uid] = nil
		Economy.add(player, pay, "Release")
		Shelf.send(player)
	end)

	Net.on("SetAutoMerge", { args = { "boolean" }, rate = 4 }, function(player, on)
		Data.update(player, function(d)
			d.autoMerge = on
		end)
		-- turning it on merges anything already waiting
		if on then
			local data = Data.get(player)
			if data then
				local groups = {}
				for _, e in data.shelf do
					groups[("%s|%d|%s|%s"):format(e.s, e.z, tostring(e.g), tostring(e.m))] = e
				end
				for _, e in groups do
					doAutoMerge(player, e.s, e.z, e.g == true, e.m)
				end
			end
			Shelf.send(player)
		end
	end)

	Data.onLoaded(function(player)
		Shelf.send(player)
	end)
	-- unanswered Shelf Full prompts are forfeited on leave: Kit.Data is already saving by then
end

return Shelf
