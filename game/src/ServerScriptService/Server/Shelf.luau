--!strict
-- The shelf (DESIGN 4.4-4.6): arrivals, auto-merge, manual merge, release, the Shelf Full choice,
-- and SQUEEZE. The save holds the shelf; squeeze cooldowns live in State (not saved).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local L = require(ReplicatedStorage.Shared.Util.ShelfLogic)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local State = require(script.Parent.State)
local Plots = require(script.Parent.Plots)
local Economy = require(script.Parent.Economy)
local Tutorial = require(script.Parent.Tutorial)
local Analytics = require(script.Parent.Analytics)

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

-- full shelf for the owner, with squeeze readiness (server time)
function Shelf.send(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local ready = State.get(player).readyAt
	local out = table.create(#data.shelf)
	for _, e in data.shelf do
		table.insert(out, { uid = e.uid, s = e.s, size = e.z, glitter = e.g, readyAt = ready[e.uid] or 0 })
	end
	Net.fire(player, "ShelfUpdate", out)
	Plots.publishShelf(player)
	Economy.refresh(player)
end

local function recordDex(d: any, s: string, z: number, g: boolean): boolean
	local entry = d.dex[s]
	local isNew = entry == nil
	if not entry then
		entry = { n = 0, best = 1, glitter = false }
		d.dex[s] = entry
	end
	entry.best = math.max(entry.best, z)
	entry.glitter = entry.glitter or g
	return isNew
end

local function announceMerge(player: Player, m: any)
	local sp = S.ById[m.s]
	Net.fire(player, "Merged", m.uid, m.s, m.z, m.g)
	Tutorial.onMerge(player)
	Analytics.custom(player, "MergeSize", m.z)
	if m.z == 3 and sp and RARITY_INDEX[sp.rarity] >= 5 then
		Net.fireAll("Announce", ("⭐ %s merged a MEGA %s!"):format(player.DisplayName, sp.name), sp.rarity)
	end
end

local function doAutoMerge(player: Player, s: string, z: number, g: boolean)
	local merged: { any } = {}
	Data.update(player, function(d)
		merged = L.autoMerge(d.shelf, s, z, g, newUid(player))
		d.stats.merges += #merged
		for _, m in merged do
			recordDex(d, m.s, m.z, m.g)
		end
	end)
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
		doAutoMerge(player, entry.s, 1, entry.g)
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
	Net.fire(player, "ShelfFull", { s = p.entry.s, size = 1, glitter = p.entry.g }, lowEntry and { uid = lowEntry.uid, s = lowEntry.s, size = lowEntry.z, glitter = lowEntry.g }, G.ShelfFullAutoSeconds)
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

-- keepNew: release the lowest-income squishy and shelve the new one; else release the new one
function Shelf.resolveFull(player: Player, keepNew: boolean)
	local st = State.get(player)
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

-- a squishy reached the shelf (called by Fling at arriveAt)
function Shelf.arrive(player: Player, s: string, g: boolean)
	local data = Data.get(player)
	if not data or not player.Parent then
		return
	end
	local isNew = false
	Data.update(player, function(d)
		isNew = recordDex(d, s, 1, g)
		d.dex[s].n += 1
		d.stats.caught += 1
	end)
	local entry = { uid = newUid(player)(), s = s, z = 1, g = g }
	local slots = E.slotCount(data.slotUpgrades)
	Tutorial.onArrive(player)
	Net.fire(player, "Arrived", entry.uid, s, g, isNew)
	if L.fits(data.shelf, slots, s, g, data.autoMerge) then
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
function Shelf.grant(player: Player, s: string, g: boolean)
	Shelf.arrive(player, s, g)
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
	Net.fire(player, "Squeezed", uids, total, now + G.SqueezeCooldown)
	Shelf.send(player)
	return total, count
end

function Shelf.start()
	Net.declare({ "ShelfUpdate", "ShelfFull", "Squeezed", "Merged", "Arrived", "Announce" })

	Net.on("SqueezeRequest", { rate = G.SqueezeRate, burst = G.SqueezeRate }, function(player)
		Shelf.squeeze(player)
	end)

	Net.on("ShelfFullChoice", { args = { "boolean" }, rate = 4 }, function(player, keepNew)
		if #State.get(player).fullQueue > 0 then
			Shelf.resolveFull(player, keepNew)
		end
	end)

	Net.on("MergeRequest", { args = { "string", "int", "boolean" }, rate = 6 }, function(player, s, z, g)
		local data = Data.get(player)
		if not data or not S.ById[s] or z < 1 or z >= L.MAX_SIZE or not L.canMerge(data.shelf, s, z, g) then
			return
		end
		local m
		Data.update(player, function(d)
			m = L.merge(d.shelf, s, z, g, newUid(player))
			if m then
				d.stats.merges += 1
				recordDex(d, m.s, m.z, m.g)
			end
		end)
		if m then
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
					groups[("%s|%d|%s"):format(e.s, e.z, tostring(e.g))] = e
				end
				for _, e in groups do
					doAutoMerge(player, e.s, e.z, e.g == true)
				end
			end
			Shelf.send(player)
		end
	end)

	Data.onLoaded(function(player)
		Shelf.send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- unanswered Shelf Full choices: keep the better one, like the auto-choice
		local st = State.get(player)
		while #st.fullQueue > 0 do
			local p = st.fullQueue[1]
			local d = Data.get(player)
			if not d then
				break
			end
			local li = lowestIndex(player, d)
			Shelf.resolveFull(player, li ~= nil and Economy.incomeOf(player, d, p.entry) > Economy.incomeOf(player, d, d.shelf[li]))
		end
	end)
end

return Shelf
