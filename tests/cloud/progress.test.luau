--!nonstrict
-- DESIGN 4.9 Re-Squish, 4.10 Goo Rain schedule, 4.11 offline cap, 4.12 calendar + quests.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local GooRain = require(RS.Shared.Util.GooRain)
	local Daily = require(RS.Shared.Util.Daily)
	local ReSquish = require(RS.Shared.Util.ReSquish)
	local Pr, E, S, Z = Config.Progress, Config.Economy, Config.Squishies, Config.Zones
	local cfg = Pr.GooRain

	t.test("goo rain: first at 4 min, every 12 min, 90 s long", function()
		t.expect(not GooRain.active(0, cfg) and GooRain.window(0, cfg).start == 240, "first window")
		t.expect(GooRain.active(240, cfg) and GooRain.active(329, cfg), "active inside")
		t.expect(not GooRain.active(330, cfg), "ends after 90 s")
		t.expect(GooRain.window(330, cfg).start == 960, "next one 12 min later")
		t.expect(GooRain.active(960 + 720 * 3 + 10, cfg), "keeps repeating")
	end)

	t.test("daily: consecutive days advance, a miss resets, same day blocks", function()
		local d = { lastClaimDay = 0, streak = 0, cycleDay = 0 }
		local ok, day, streak = Daily.status(d, 100)
		t.expect(ok and day == 1 and streak == 1, "first claim")
		d = { lastClaimDay = 100, streak = 1, cycleDay = 1 }
		ok = Daily.status(d, 100)
		t.expect(not ok, "already claimed today")
		ok, day, streak = Daily.status(d, 101)
		t.expect(ok and day == 2 and streak == 2, "next day")
		ok, day, streak = Daily.status({ lastClaimDay = 106, streak = 7, cycleDay = 7 }, 107)
		t.expect(ok and day == 1 and streak == 8, "after day 7 the cycle repeats, streak keeps counting")
		ok, day, streak = Daily.status({ lastClaimDay = 100, streak = 5, cycleDay = 5 }, 102)
		t.expect(ok and day == 1 and streak == 1, "missed a day resets")
	end)

	t.test("daily coins: max(min, minutes of income)", function()
		t.expect(Daily.coins(Pr.Daily[1], 0) == 400, "floor")
		t.expect(Daily.coins(Pr.Daily[1], 10) == 3000, "5 min at 10/s")
	end)

	t.test("quests: 3 distinct, stable per player and day", function()
		local a = Daily.pickQuests(Pr.Quests, 3, 2000, 12345)
		local b = Daily.pickQuests(Pr.Quests, 3, 2000, 12345)
		t.expect(#a == 3 and a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3], "distinct")
		t.expect(a[1] == b[1] and a[2] == b[2] and a[3] == b[3], "stable")
		local q = { day = 0, list = {} }
		t.expect(Daily.refreshQuests(q, Pr.Quests, 3, 2000, 1) and #q.list == 3, "reset on a new day")
		q.list[1].n = 4
		t.expect(not Daily.refreshQuests(q, Pr.Quests, 3, 2000, 1) and q.list[1].n == 4, "same day keeps progress")
	end)

	t.test("day 7 roll only gives Epic / Legendary / Mythic", function()
		local odds = Pr.Daily[7].odds
		t.expect(Daily.rollRarity(odds, Z.Rarities, 0) == "Epic", "low end")
		t.expect(Daily.rollRarity(odds, Z.Rarities, 0.75) == "Legendary", "middle")
		t.expect(Daily.rollRarity(odds, Z.Rarities, 0.999) == "Mythic", "top end")
	end)

	t.test("re-squish: needs coins and a Legendary+, resets exactly 4.9", function()
		local d = {
			coins = E.reSquishCost(1), sp = 900, goo = 5, gloves = 4, slotUpgrades = 6, shelfLevel = 3, reSquishes = 0,
			shelf = { { uid = "1", s = "bao_bun", z = 1, g = false } }, dex = { bao_bun = { n = 3, best = 2 } },
			autoMerge = false, daily = { streak = 4 }, stats = { flings = 50 },
		}
		local coinsOk, legOk = ReSquish.check(d, E, S, Z.Rarities)
		t.expect(coinsOk and not legOk, "no Legendary yet")
		table.insert(d.shelf, { uid = "2", s = "galaxy_cat", z = 1, g = false })
		coinsOk, legOk = ReSquish.check(d, E, S, Z.Rarities)
		t.expect(coinsOk and legOk, "ready")
		ReSquish.apply(d)
		t.expect(d.reSquishes == 1 and d.coins == 0 and d.sp == 1 and d.goo == 1 and d.gloves == 1, "resets progress")
		t.expect(#d.shelf == 0 and d.slotUpgrades == 0 and d.shelfLevel == 1, "resets shelf")
		t.expect(d.dex.bao_bun.n == 3 and d.autoMerge == false and d.daily.streak == 4 and d.stats.flings == 50, "keeps the rest")
		t.expect(ReSquish.cost(d, E) == E.reSquishCost(2) and ReSquish.incomeMult(2, E) == 2, "next cost, x1.5 per Re-Squish")
	end)

	t.test("offline: 50% for at most 6 h", function()
		t.expect(Pr.Offline.Rate == 0.5 and Pr.Offline.CapSeconds == 21600, "spec values")
	end)
end
