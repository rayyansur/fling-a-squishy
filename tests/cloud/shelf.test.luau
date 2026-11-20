--!nonstrict
-- DESIGN 4.5 + 4.6: merging, slots, the Shelf Full choice.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local L = require(RS.Shared.Util.ShelfLogic)
	local E = Config.Economy

	local n = 0
	local function uid()
		n += 1
		return "u" .. n
	end
	local function e(s, z, g)
		return { uid = uid(), s = s, z = z or 1, g = g or false }
	end

	t.test("3 identical merge into 1 of the next size and free 2 slots", function()
		local shelf = { e("bao_bun"), e("bao_bun"), e("mochi_blob"), e("bao_bun") }
		local m = L.merge(shelf, "bao_bun", 1, false, uid)
		t.expect(m and m.z == 2, "chonky")
		t.expect(#shelf == 2, "4 -> 2 entries")
	end)

	t.test("glitter and size must match", function()
		local shelf = { e("bao_bun"), e("bao_bun"), e("bao_bun", 1, true), e("bao_bun", 2) }
		t.expect(not L.canMerge(shelf, "bao_bun", 1, false), "only 2 plain normals")
	end)

	t.test("auto-merge chains Normal -> Chonky -> Mega, and Mega is the max", function()
		local shelf = {}
		for _ = 1, 2 do
			table.insert(shelf, e("taco_pup", 2))
		end
		for _ = 1, 3 do
			table.insert(shelf, e("taco_pup", 1))
		end
		local made = L.autoMerge(shelf, "taco_pup", 1, false, uid)
		t.expect(#made == 2 and made[2].z == 3, "chonky then mega")
		t.expect(#shelf == 1 and shelf[1].z == 3, "one mega left")
		table.insert(shelf, e("taco_pup", 3))
		table.insert(shelf, e("taco_pup", 3))
		t.expect(not L.canMerge(shelf, "taco_pup", 3, false), "mega can't merge")
	end)

	t.test("a full shelf still fits a squishy that auto-merges", function()
		local shelf = {}
		for i = 1, 8 do
			table.insert(shelf, e(if i <= 2 then "bao_bun" else "jelly_bean", 1, i > 2 and i % 2 == 0))
		end
		t.expect(L.fits(shelf, 8, "bao_bun", false, true), "merges into the pair")
		t.expect(not L.fits(shelf, 8, "bao_bun", false, false), "auto-merge off: full")
		t.expect(not L.fits(shelf, 8, "mochi_blob", false, true), "no pair: full")
	end)

	t.test("slots: 8 + 2 per upgrade up to 40, cost floor(120 * 2.1^k)", function()
		t.expect(E.slotCount(0) == 8 and E.slotCount(16) == 40 and E.slotCount(20) == 40, "slot counts")
		t.expect(E.MaxSlotUpgrades == 16, "16 upgrades")
		t.expect(E.slotCost(0) == 120 and E.slotCost(1) == 252 and E.slotCost(2) == 529, "costs")
	end)
end
