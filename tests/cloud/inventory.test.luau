--!nonstrict
-- Inventory (DESIGN 22): Equip Best picks the top earners, keeps shelf order and ties, and never
-- loses or duplicates a squishy.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local L = require(RS.Shared.Util.ShelfLogic)
	local G = Config.Game

	local function incomeOf(e)
		return e.v
	end
	local function uids(list)
		local out = {}
		for _, e in list do
			table.insert(out, e.uid)
		end
		return table.concat(out, ",")
	end

	t.test("Equip Best moves the top earners onto the shelf", function()
		local shelf = { { uid = "a", v = 5 }, { uid = "b", v = 1 }, { uid = "c", v = 3 } }
		local inv = { { uid = "x", v = 10 }, { uid = "y", v = 2 }, { uid = "z", v = 4 } }
		local s2, i2 = L.equipBest(shelf, inv, 3, incomeOf)
		t.expect(uids(s2) == "a,x,z", "shelf " .. uids(s2))
		t.expect(uids(i2) == "b,c,y", "inv " .. uids(i2))
	end)

	t.test("ties keep what's already on the shelf, nothing is lost", function()
		local shelf = { { uid = "a", v = 2 }, { uid = "b", v = 2 } }
		local inv = { { uid = "x", v = 2 }, { uid = "y", v = 1 } }
		local s2, i2 = L.equipBest(shelf, inv, 2, incomeOf)
		t.expect(uids(s2) == "a,b", "shelf " .. uids(s2))
		t.expect(#s2 + #i2 == 4, "count kept")
	end)

	t.test("a bigger shelf takes everything", function()
		local s2, i2 = L.equipBest({ { uid = "a", v = 1 } }, { { uid = "x", v = 3 } }, 8, incomeOf)
		t.expect(#s2 == 2 and #i2 == 0, "all equipped")
	end)

	t.test("inventory is saved, capped and reset by Re-Squish", function()
		t.expect(type(Config.Data.defaults.inv) == "table", "save default")
		t.expect(G.InventoryCap >= 50 and G.InventoryCap <= 1000, "cap " .. G.InventoryCap)
		local R = require(RS.Shared.Util.ReSquish)
		local d = { reSquishes = 0, shelf = { 1 }, inv = { 1, 2 } }
		R.apply(d)
		t.expect(#d.inv == 0, "Re-Squish clears the inventory")
	end)
end
