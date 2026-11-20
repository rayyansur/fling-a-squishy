--!nonstrict
-- DESIGN 4.3: renormalized weights, bounce and Goo Rain luck, zero weights never roll.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local Rarity = require(RS.Shared.Util.Rarity)
	local Z = Config.Zones

	local function sum(w)
		local s = 0
		for _, v in w do
			s += v
		end
		return s
	end

	t.test("no luck = the table", function()
		local w = Rarity.weights(Z, 3, 0, false, 1.25)
		t.expect(math.abs(w.Rare - 20) < 1e-9 and math.abs(w.Common - 35) < 1e-9, "zone 3 odds")
		t.expect(math.abs(sum(w) - 100) < 1e-9, "sums to 100")
	end)

	t.test("3 bounces = Rare+ x1.953, renormalized", function()
		local w = Rarity.weights(Z, 2, 3, false, 1.25)
		local f = 1.25 ^ 3
		local total = 60 + 32 + 8 * f
		t.expect(math.abs(w.Rare - 8 * f / total * 100) < 1e-9, "rare " .. w.Rare)
		t.expect(math.abs(sum(w) - 100) < 1e-9, "sums to 100")
	end)

	t.test("Goo Rain stacks x2 with bounce luck", function()
		local w = Rarity.weights(Z, 4, 1, true, 1.25)
		local f = 1.25 * 2
		local total = 35 + (40 + 20 + 5) * f
		t.expect(math.abs(w.Legendary - 5 * f / total * 100) < 1e-9, "legendary " .. w.Legendary)
	end)

	t.test("zero-weight rarities never roll", function()
		local w = Rarity.weights(Z, 1, 3, true, 1.25)
		for i = 0, 999 do
			local r = Rarity.pick(w, Z.Rarities, i / 1000)
			t.expect(r == "Common" or r == "Uncommon", "rolled " .. r .. " in zone 1")
		end
		local w6 = Rarity.weights(Z, 6, 0, false, 1.25)
		for i = 0, 999 do
			local r = Rarity.pick(w6, Z.Rarities, i / 1000)
			t.expect(r == "Epic" or r == "Legendary" or r == "Mythic", "rolled " .. r .. " in zone 6")
		end
	end)
end
