--!nocheck
-- DESIGN 14 balance sim: one player, hold + reload per throw (DESIGN 19), 60% perfect, random aim within the
-- clamp (the real pad layout decides bounces), squeeze every 10 s, Auto-Merge on, greedy
-- cheapest-first purchases. Prints when each milestone lands vs the spec target.
--   lune run tests/local/run.luau balance
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local T = require(RS.Shared.Util.Trajectory)
	local Rarity = require(RS.Shared.Util.Rarity)
	local L = require(RS.Shared.Util.ShelfLogic)
	local Income = require(RS.Shared.Util.Income)
	local G, M, E, S, Z = Config.Game, Config.Map, Config.Economy, Config.Squishies, Config.Zones
	local override = tonumber(require("@lune/process").env.FAS_DIST_PER_ROOT_SP)
	if override then
		E = table.clone(E)
		E.DistPerRootSP = override
		print("DistPerRootSP override: " .. override)
	end

	local costMult = tonumber(require("@lune/process").env.FAS_COST_MULT)
	if costMult then
		E = table.clone(E)
		local function scaled(list)
			local out = {}
			for i, v in list do
				local c = table.clone(v)
				c.cost = math.floor(v.cost * costMult)
				out[i] = c
			end
			return out
		end
		E.Goo, E.Gloves, E.ShelfLevels = scaled(E.Goo), scaled(E.Gloves), scaled(E.ShelfLevels)
		local base = E.Slots.base * costMult
		E.slotCost = function(k) return math.floor(base * E.Slots.growth ^ k) end
		local rs = table.clone(E.ReSquish)
		rs.base *= costMult
		E.ReSquish = rs
		E.reSquishCost = function(n) return rs.base * rs.growth ^ (n - 1) end
		print("cost override x" .. costMult)
	end

	local env = require("@lune/process").env
	local slotGrowth, rsBase = tonumber(env.FAS_SLOT_GROWTH), tonumber(env.FAS_RESQUISH_BASE)
	if slotGrowth then
		E = table.clone(E)
		local prev = E.slotCost
		local base = tonumber(env.FAS_SLOT_BASE) or prev(0)
		E.slotCost = function(k) return math.floor(base * slotGrowth ^ k) end
		print("slot growth " .. slotGrowth)
	end
	if rsBase then
		E = table.clone(E)
		local rs = table.clone(E.ReSquish)
		rs.base = rsBase
		E.ReSquish = rs
		E.reSquishCost = function(n) return rs.base * rs.growth ^ (n - 1) end
		print("re-squish base " .. rsBase)
	end

	local function run(seed: number)
		local rng = Random.new(seed)
		local d = { coins = 0, sp = 1, goo = 1, gloves = 1, sling = 1, slotUpgrades = 0, shelfLevel = 1, reSquishes = 0, shelf = {} }
		local rules = T.rulesFrom(M)
		local fp = M.flingPoint(6)
		local start = Vector3.new(fp[1], fp[2], fp[3])
		local uid = 0
		local function newUid()
			uid += 1
			return tostring(uid)
		end
		local seen = {}
		local now, lastSqueeze = 0, 0
		local function incomeOf(e)
			return Income.of(e, S, Z, Income.mults(d, E, false, false, 1, 1))
		end
		local function mark(key)
			if not seen[key] then
				seen[key] = now
			end
		end
		local streak = 0
		while now < 4 * 3600 do
			-- throw (DESIGN 19): hold to the sweet spot (60%) or release early, then the reload
			local perfect = rng:NextNumber() < 0.6
			local hold = if perfect then G.SweetSpot * G.ChargeCycle / 2 + 0.08 else rng:NextNumber(G.MinHold, G.SweetSpot * G.ChargeCycle / 2)
			now += hold + G.FlingCooldown + 0.1
			local c = T.chargeAt(hold, G.ChargeCycle)
			local curve
			curve, perfect = T.chargeCurve(c, G.SweetSpot, E.ChargeFloor, E.PerfectMult)
			streak = if perfect then math.min(G.PerfectStreakMax, streak + 1) else 0
			local len = T.power(d.sp, E.Goo[d.goo].mult * E.Slingshots[d.sling].mult, d.reSquishes, false, E) * curve
			if perfect then
				len *= T.streakMult(streak, G.PerfectStreakDist)
			end
			local path = T.compute(start, T.direction(rng:NextNumber(-G.AimClampDeg, G.AimClampDeg)), len, M.JellyPads, rules)
			local zone = T.zoneOf(path.distance, Z.List)
			if zone >= 6 then
				mark("Rainbow Rim")
			end
			d.sp += E.Gloves[d.gloves].sp * (if perfect then E.PerfectSP else 1)
			local rarity = Rarity.pick(Rarity.weights(Z, zone, path.bounces, false, M.BounceLuckPerBounce), Z.Rarities, rng:NextNumber())
			local pool = S.ByRarity[rarity]
			local s = pool[rng:NextInteger(1, #pool)].id
			local g = rng:NextNumber() < Z.GlitterChance
			mark("first " .. rarity)
			-- shelf (arrival is immediate in the sim)
			local slots = E.slotCount(d.slotUpgrades)
			local entry = { uid = newUid(), s = s, z = 1, g = g }
			if L.fits(d.shelf, slots, s, g, true) then
				table.insert(d.shelf, entry)
				for _, m in L.autoMerge(d.shelf, s, 1, g, newUid) do
					mark(if m.z == 2 then "first Chonky" else "first Mega")
				end
			else
				local lo = L.lowest(d.shelf, incomeOf)
				if lo and incomeOf(d.shelf[lo]) < incomeOf(entry) then
					d.shelf[lo] = entry
				end
			end
			-- income + squeeze burst
			local ips = Income.total(d.shelf, S, Z, Income.mults(d, E, false, false, 1, 1))
			d.coins += ips * 0.9
			if now - lastSqueeze >= G.SqueezeCooldown then
				lastSqueeze = now
				d.coins += ips * G.SqueezeSeconds
			end
			-- greedy purchases, cheapest first
			local bought = true
			while bought do
				bought = false
				local opts = {}
				if E.Goo[d.goo + 1] then
					table.insert(opts, { E.Goo[d.goo + 1].cost, function() d.goo += 1; mark("goo " .. d.goo) end })
				end
				if E.Slingshots[d.sling + 1] then
					table.insert(opts, { E.Slingshots[d.sling + 1].cost, function() d.sling += 1; mark("sling " .. d.sling) end })
				end
				if E.Gloves[d.gloves + 1] then
					table.insert(opts, { E.Gloves[d.gloves + 1].cost, function() d.gloves += 1; mark("gloves " .. d.gloves) end })
				end
				if d.slotUpgrades < E.MaxSlotUpgrades then
					table.insert(opts, { E.slotCost(d.slotUpgrades), function() d.slotUpgrades += 1 end })
				end
				if E.ShelfLevels[d.shelfLevel + 1] then
					table.insert(opts, { E.ShelfLevels[d.shelfLevel + 1].cost, function() d.shelfLevel += 1 end })
				end
				table.sort(opts, function(a, b) return a[1] < b[1] end)
				local o = opts[1]
				if o and d.coins >= o[1] then
					d.coins -= o[1]
					o[2]()
					bought = true
				end
			end
			if E.slotCount(d.slotUpgrades) >= 20 then
				mark("20 slots")
			end
			if d.coins >= E.reSquishCost(0) then
				mark("Re-Squish affordable")
			end
		end
		return seen
	end

	local TARGETS = {
		{ "goo 2", 0, 90 }, { "gloves 2", 0, 3 * 60 }, { "goo 3", 0, 15 * 60 },
		{ "first Rare", 0, 5 * 60 }, { "first Chonky", 0, 6 * 60 }, { "first Epic", 0, 20 * 60 },
		{ "first Legendary", 0, 60 * 60 }, { "20 slots", 45 * 60 * 0.7, 45 * 60 * 1.3 },
		{ "Rainbow Rim", 1.5 * 3600, 2.5 * 3600 }, { "Re-Squish affordable", 3 * 3600, 4 * 3600 },
	}
	local runs = {}
	for seed = 1, 5 do
		table.insert(runs, run(seed))
	end
	local function median(key)
		local v = {}
		for _, r in runs do
			table.insert(v, r[key] or math.huge)
		end
		table.sort(v)
		return v[3]
	end
	local function fmt(s)
		if s == math.huge then
			return "never (4h)"
		end
		return ("%dm%02ds"):format(s // 60, math.floor(s % 60))
	end
	t.test("balance sim (median of 5 runs)", function()
		local lines = {}
		for _, tg in TARGETS do
			local m = median(tg[1])
			local ok = m >= tg[2] * 0.7 and m <= tg[3] * 1.3
			table.insert(lines, ("%-22s %-12s target %s-%s %s"):format(tg[1], fmt(m), fmt(tg[2]), fmt(tg[3]), if ok then "ok" else "OFF"))
		end
		print(table.concat(lines, "\n"))
	end)
end
