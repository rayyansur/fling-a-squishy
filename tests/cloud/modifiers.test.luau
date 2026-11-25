--!nonstrict
-- Rare modifiers (DESIGN 21): odds, income, merging only like with like, titles and moments.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local Mod = require(RS.Shared.Util.Modifier)
	local L = require(RS.Shared.Util.ShelfLogic)
	local Income = require(RS.Shared.Util.Income)
	local Z, S, E = Config.Zones, Config.Squishies, Config.Economy

	t.test("modifiers are rarer the stronger they are", function()
		for i = 2, #Z.Modifiers do
			t.expect(Z.Modifiers[i].chance > Z.Modifiers[i - 1].chance, "chance order at " .. i)
			t.expect(Z.Modifiers[i].mult < Z.Modifiers[i - 1].mult, "mult order at " .. i)
		end
		local total = 0
		for _, m in Z.Modifiers do
			total += m.chance
		end
		t.expect(total < 0.1, "most catches have no modifier")
	end)

	t.test("roll: thresholds, nothing above them, bounces raise the odds", function()
		t.expect(Mod.roll(Z, 0, 0) == "galactic", "lowest roll is Galactic")
		t.expect(Mod.roll(Z, 0.5, 0) == nil, "a middle roll is plain")
		local edge = Z.ModifierById.galactic.chance + Z.ModifierById.giant.chance + Z.ModifierById.big.chance
		t.expect(Mod.roll(Z, edge - 1e-6, 0) == "big", "just under the edge is Big")
		t.expect(Mod.roll(Z, edge + 1e-6, 0) == nil, "just over is plain")
		t.expect(Mod.roll(Z, edge + 1e-6, 3) == "big", "3 bounces widen the window")
	end)

	t.test("income multiplies by modifier and Shiny", function()
		local m = Income.mults({ shelfLevel = 1, reSquishes = 0 }, E, false, false, 1, 1)
		local plain = Income.of({ s = "bao_bun", z = 1 }, S, Z, m)
		local giant = Income.of({ s = "bao_bun", z = 1, m = "giant" }, S, Z, m)
		local both = Income.of({ s = "bao_bun", z = 1, m = "galactic", g = true }, S, Z, m)
		t.expect(giant == plain * Z.ModifierById.giant.mult, "giant mult")
		t.expect(both == plain * Z.ModifierById.galactic.mult * Z.GlitterMult, "galactic shiny")
	end)

	t.test("merges only combine the same modifier", function()
		local n = 0
		local uid = function()
			n += 1
			return "u" .. n
		end
		local shelf = {
			{ uid = "a", s = "bao_bun", z = 1, g = false, m = "big" },
			{ uid = "b", s = "bao_bun", z = 1, g = false, m = "big" },
			{ uid = "c", s = "bao_bun", z = 1, g = false },
		}
		t.expect(not L.canMerge(shelf, "bao_bun", 1, false, "big"), "two Big + one plain can't merge")
		table.insert(shelf, { uid = "d", s = "bao_bun", z = 1, g = false, m = "big" })
		local merged = L.merge(shelf, "bao_bun", 1, false, uid, "big")
		t.expect(merged and merged.m == "big" and merged.z == 2, "Big Chonky")
		t.expect(#shelf == 2, "plain one left alone")
	end)

	t.test("titles and catch moments", function()
		t.expect(Mod.title(Z, S, "boba_bear", 2, true, "giant") == "Giant Shiny Chonky Boba Bear", Mod.title(Z, S, "boba_bear", 2, true, "giant"))
		t.expect(Mod.moment(Z, "Common", false, nil) == 0, "plain common: nothing")
		t.expect(Mod.moment(Z, "Common", false, "big") == 1, "big common: card")
		t.expect(Mod.moment(Z, "Common", false, "galactic") == 2, "galactic: full reveal")
		t.expect(Mod.moment(Z, "Legendary", false, nil) == 2, "legendary: full reveal")
		t.expect(Mod.clean(Z, "") == nil and Mod.clean(Z, "bogus") == nil, "clean")
	end)
end
