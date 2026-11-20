--!nonstrict
-- DESIGN 4.8 income formula, 4.4 squeeze payout.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local Income = require(RS.Shared.Util.Income)
	local S, Z, E, Mo = Config.Squishies, Config.Zones, Config.Economy, Config.Monetization

	t.test("final income multiplies every factor", function()
		local data = { shelfLevel = 3, reSquishes = 2 }
		local m = Income.mults(data, E, true, true, Mo.CoinsPassMult, Mo.PartyMult)
		local v = Income.of({ s = "boba_bear", z = 2, g = true }, S, Z, m)
		-- 14 x 4 (Chonky) x 3 (Glitter) x 1.25 (shelf L3) x 2.0 (Re-Squish 2) x 2 (pass) x 2 (party)
		t.expect(math.abs(v - 14 * 4 * 3 * 1.25 * 2 * 2 * 2) < 1e-6, "got " .. v)
	end)

	t.test("plain Normal squishy pays its base", function()
		local m = Income.mults({ shelfLevel = 1, reSquishes = 0 }, E, false, false, 2, 2)
		t.expect(Income.of({ s = "jelly_bean", z = 1, g = false }, S, Z, m) == 1.5, "1.5/s")
		t.expect(Income.of({ s = "nope", z = 1 }, S, Z, m) == 0, "unknown = 0")
	end)

	t.test("squeeze pays 5 s of income", function()
		local m = Income.mults({ shelfLevel = 1, reSquishes = 0 }, E, false, false, 2, 2)
		local per = Income.of({ s = "mega_mochi", z = 3 }, S, Z, m)
		t.expect(per * Config.Game.SqueezeSeconds == 1000 * 16 * 5, "mega mochi burst")
	end)
end
