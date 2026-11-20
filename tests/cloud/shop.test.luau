--!nonstrict
-- PR 3 Shop (DESIGN 10): catalog sizes per GUIDELINES, coin pack amounts, Squish Party stacking
-- and its 30 min cap, the party changes income only (never odds), and 2x Coins doubles income.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local SSS = game:GetService("ServerScriptService")
	local Config = require(RS.Shared.Config)
	local Products = require(RS.Kit.Products)
	local Income = require(RS.Shared.Util.Income)
	local Rarity = require(RS.Shared.Util.Rarity)
	local Economy = require(SSS.Server.Economy)
	local Store = require(SSS.Server.Store)
	local Mo, Z, M = Config.Monetization, Config.Zones, Config.Map

	t.test("2-4 passes and 2-4 products; every coin pack has numbers", function()
		local np, nd = #Products.list("passes"), #Products.list("products")
		t.expect(np >= 2 and np <= 4, "passes: " .. np)
		t.expect(nd >= 2 and nd <= 4, "products: " .. nd)
		for key in Mo.CoinPacks do
			t.expect(Products.get("products", key) ~= nil, key .. " missing from monetization.json")
		end
		t.expect(Products.get("products", "squish_party") ~= nil, "squish_party missing")
	end)

	t.test("coin packs pay max(floor, minutes of base income)", function()
		for key, p in Mo.CoinPacks do
			t.expect(Store.packAmount(key, 0) == p.floor, key .. " floor at 0 income")
			local rich = p.floor -- coins per second, so N minutes is far above the floor
			t.expect(Store.packAmount(key, rich) == rich * p.minutes * 60, key .. " scales with income")
		end
		t.expect(Store.packAmount("coin_tub", 1) > Store.packAmount("coin_jar", 1), "tub > jar")
		t.expect(Store.packAmount("coin_jar", 1) > Store.packAmount("coin_bag", 1), "jar > bag")
	end)

	t.test("squish party: +5 min per buy, stacks, capped at 30 min", function()
		local now = 1000
		local u = Store.extendParty(0, now)
		t.expect(u == now + 300, "first buy = 5 min, got " .. (u - now))
		u = Store.extendParty(u, now + 60)
		t.expect(u == now + 600, "second buy stacks, got " .. (u - now))
		for _ = 1, 10 do
			u = Store.extendParty(u, now)
		end
		t.expect(u == now + Mo.PartyMaxMinutes * 60, "cap at 30 min, got " .. (u - now))
		t.expect(Store.extendParty(now - 50, now) == now + 300, "an ended party restarts from now")
	end)

	t.test("party and 2x Coins multiply income; odds don't change", function()
		local data = { shelfLevel = 1, reSquishes = 0 }
		local plain = Income.mults(data, Config.Economy, false, false, Mo.CoinsPassMult, Mo.PartyMult)
		local both = Income.mults(data, Config.Economy, true, true, Mo.CoinsPassMult, Mo.PartyMult)
		t.expect(both.pass == 2 and both.party == 2 and plain.pass == 1 and plain.party == 1, "multipliers")
		local before = Rarity.weights(Z, 3, 1, false, M.BounceLuckPerBounce)
		local saved = Economy.partyUntil
		Economy.partyUntil = workspace:GetServerTimeNow() + 60
		t.expect(Economy.partyActive(), "party active")
		local during = Rarity.weights(Z, 3, 1, false, M.BounceLuckPerBounce)
		Economy.partyUntil = saved
		for k, v in before do
			t.expect(during[k] == v, "odds changed for " .. tostring(k))
		end
	end)

	t.test("abbrev keeps whole hundreds (270K, not 27K)", function()
		local Format = require(RS.Shared.Util.Format)
		local cases = { [100000] = "100K", [270000] = "270K", [67500] = "67.5K", [1000] = "1K", [2.5e9] = "2.5B", [10000] = "10K", [500e6] = "500M" }
		for n, want in cases do
			t.expect(Format.abbrev(n) == want, ("abbrev(%d) = %s, want %s"):format(n, Format.abbrev(n), want))
		end
	end)

	t.test("PartyUntil is published for clients", function()
		t.waitFor(function()
			return workspace:GetAttribute("PartyUntil") ~= nil
		end, 20)
	end)
end
