--!strict
-- The shelf and inventory (DESIGN 4.4-4.6, 22): arrivals, auto-merge, manual merge, sell, the
-- inventory (overflow when the shelf is full), equip / store / Equip Best, and SQUEEZE. The save
-- holds both lists; squeeze cooldowns live in State (not saved) and follow a squishy between them.
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

-- full shelf for the owner, with squeeze readiness (server time)
function Shelf.send(player: Player)
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

local function wire(e: any): any
	return { uid = e.uid, s = e.s, size = e.z, glitter = e.g, mod = e.m }
end

-- the inventory list for the owner (only sent when it changes)
function Shelf.sendInv(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local out = table.create(#data.inv)
	for _, e in data.inv do
		table.insert(out, wire(e))
	end
	player:SetAttribute("InvCount", #data.inv)
	Net.fire(player, "InvUpdate", out)
end

local function sellValue(player: Player, data: any, e: any): number
	return Economy.incomeOf(player, data, e) * G.ReleaseSeconds
end

-- overflow: the squishy goes to the inventory (and merges there); a full inventory sells it
local function toInventory(player: Player, entry: any)
	local data = Data.get(player)
	if not data then
		return
	end
	if #data.inv >= G.InventoryCap then
		local pay = sellValue(player, data, entry)
		Economy.add(player, pay, "Release")
		Net.fire(player, "ToInventory", entry.s, entry.g, entry.m or "", pay)
		return
	end
	local merged: { any } = {}
	Data.update(player, function(d)
		table.insert(d.inv, entry)
		if d.autoMerge then
			merged = L.autoMerge(d.inv, entry.s, 1, entry.g, uidFrom(d), entry.m)
			d.stats.merges += #merged
			for _, m in merged do
				recordDex(d, m.s, m.z, m.g, m.m)
			end
		end
	end)
	for _, m in merged do
		announceMerge(player, m)
	end
	Net.fire(player, "ToInventory", entry.s, entry.g, entry.m or "", 0)
	Shelf.sendInv(player)
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
		toInventory(player, entry)
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
	Net.declare({ "ShelfUpdate", "InvUpdate", "ToInventory", "Sold", "Squeezed", "Merged", "Arrived", "Announce", "DexState" })

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

	-- inInv: merge three in the inventory instead of on the shelf
	Net.on("MergeRequest", { args = { "string", "int", "boolean", "string", "boolean" }, rate = 6, maxString = 24 }, function(player, s, z, g, modStr, inInv)
		local mod = Mod.clean(Config.Zones, modStr)
		local data = Data.get(player)
		local list = data and (if inInv then data.inv else data.shelf)
		if not data or not list or not S.ById[s] or z < 1 or z >= L.MAX_SIZE or not L.canMerge(list, s, z, g, mod) then
			return
		end
		if inInv then
			local made
			Data.update(player, function(d)
				made = L.merge(d.inv, s, z, g, uidFrom(d), mod)
				if made then
					d.stats.merges += 1
					recordDex(d, made.s, made.z, made.g, made.m)
				end
			end)
			if made then
				announceMerge(player, made)
				Shelf.sendInv(player)
			end
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

	-- sell one squishy (shelf or inventory); all = every inventory squishy like it
	Net.on("SellSquishy", { args = { "string", "boolean" }, rate = 8, maxString = 16 }, function(player, uid, all)
		local data = Data.get(player)
		if not data then
			return
		end
		local si = L.find(data.shelf, uid)
		local ii = if si then nil else L.find(data.inv, uid)
		if not si and not ii then
			return
		end
		local pay = 0
		if si then
			pay = sellValue(player, data, data.shelf[si])
			Data.update(player, function(d)
				table.remove(d.shelf, si)
			end)
			State.get(player).readyAt[uid] = nil
		else
			local like = data.inv[ii :: number]
			Data.update(player, function(d)
				for k = #d.inv, 1, -1 do
					local e = d.inv[k]
					if e.uid == uid or (all and e.s == like.s and e.z == like.z and (e.g == true) == (like.g == true) and e.m == like.m) then
						pay += sellValue(player, d, e)
						State.get(player).readyAt[e.uid] = nil
						table.remove(d.inv, k)
					end
				end
			end)
			Shelf.sendInv(player)
		end
		Economy.add(player, pay, "Release")
		Net.fire(player, "Sold", pay)
		Shelf.send(player)
	end)

	-- shelf -> inventory
	Net.on("StoreSquishy", { args = { "string" }, rate = 8, maxString = 16 }, function(player, uid)
		local data = Data.get(player)
		local i = data and L.find(data.shelf, uid)
		if not data or not i or #data.inv >= G.InventoryCap then
			return
		end
		Data.update(player, function(d)
			table.insert(d.inv, table.remove(d.shelf, i))
		end)
		Shelf.sendInv(player)
		Shelf.send(player)
	end)

	-- inventory -> shelf; a full shelf swaps out its lowest earner
	Net.on("EquipSquishy", { args = { "string" }, rate = 8, maxString = 16 }, function(player, uid)
		local data = Data.get(player)
		local i = data and L.find(data.inv, uid)
		if not data or not i then
			return
		end
		local slots = E.slotCount(data.slotUpgrades)
		local low = if #data.shelf >= slots then lowestIndex(player, data) else nil
		Data.update(player, function(d)
			local e = table.remove(d.inv, i)
			if low then
				table.insert(d.inv, table.remove(d.shelf, low))
			end
			table.insert(d.shelf, e)
		end)
		Shelf.sendInv(player)
		Shelf.send(player)
	end)

	Net.on("EquipBest", { rate = 2, burst = 3 }, function(player)
		local data = Data.get(player)
		if not data then
			return
		end
		local slots = E.slotCount(data.slotUpgrades)
		Data.update(player, function(d)
			d.shelf, d.inv = L.equipBest(d.shelf, d.inv, slots, function(e)
				return Economy.incomeOf(player, d, e)
			end)
		end)
		Shelf.sendInv(player)
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
		Data.update(player, function(d)
			d.inv = d.inv or {}
		end)
		Shelf.send(player)
		Shelf.sendInv(player)
	end)
end

return Shelf
