--!nocheck
-- DESIGN 14 balance sim: one player, a fling every 0.9 s, 60% perfect, random aim within the
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

	local function run(seed: number)
		local rng = Random.new(seed)
		local d = { coins = 0, sp = 1, goo = 1, gloves = 1, slotUpgrades = 0, shelfLevel = 1, reSquishes = 0, shelf = {} }
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
		while now < 4 * 3600 do
			now += 0.9
			-- fling
			local c = if rng:NextNumber() < 0.6 then G.SweetSpot else rng:NextNumber(E.ChargeFloor, 1)
			local curve = T.chargeCurve(c, G.SweetSpot, E.ChargeFloor)
			local len = T.power(d.sp, E.Goo[d.goo].mult, d.reSquishes, false, E) * curve
			local path = T.compute(start, T.direction(rng:NextNumber(-G.AimClampDeg, G.AimClampDeg)), len, M.JellyPads, rules)
			local zone = T.zoneOf(path.distance, Z.List)
			if zone >= 6 then
				mark("Rainbow Rim")
			end
			d.sp += E.Gloves[d.gloves].sp
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
					table.insert(opts, { E.Goo[d.goo + 1].cost, function() d.goo += 1 end })
				end
				if E.Gloves[d.gloves + 1] then
					table.insert(opts, { E.Gloves[d.gloves + 1].cost, function() d.gloves += 1 end })
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
