--!nonstrict
-- Kit crash tests: run inside a real Roblox server with every game's own suites.
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = game:GetService("HttpService")
	local Net = require(ReplicatedStorage.Kit.Net)
	local Odds = require(ReplicatedStorage.Kit.Odds)
	local Products = require(ReplicatedStorage.Kit.Products)
	local Catalog = require(ReplicatedStorage.Kit.Catalog)
	local Data = require(ServerScriptService.Kit.Data)
	local Shop = require(ServerScriptService.Kit.Shop)
	local Leaderboard = require(ServerScriptService.Kit.Leaderboard)

	t.test("kit: Net rejects bad arguments", function()
		local spec = { args = { "string", "int" }, maxString = 5 }
		t.expect(Net.check(spec, { "seed", 3 }, 2), "valid call rejected")
		t.expect(not Net.check(spec, { "seed", 3.5 }, 2), "fractional int accepted")
		t.expect(not Net.check(spec, { "seed", 0 / 0 }, 2), "NaN accepted")
		t.expect(not Net.check(spec, { "seed", math.huge }, 2), "inf accepted")
		t.expect(not Net.check(spec, { "seed" }, 1), "missing arg accepted")
		t.expect(not Net.check(spec, { "seed", 1, "extra" }, 3), "extra arg accepted")
		t.expect(not Net.check(spec, { "toolong", 1 }, 2), "long string accepted")
		t.expect(not Net.check(spec, { 5, 1 }, 2), "number accepted as string")
		t.expect(not Net.check({ args = { "Vector3" } }, { Vector3.new(0 / 0, 0, 0) }, 1), "NaN Vector3 accepted")
		t.expect(Net.check({}, {}, 0), "no-arg call rejected")
	end)

	t.test("kit: Net rate limit", function()
		local lim = Net.limiter(2, 2)
		local first, second = lim(0), lim(0)
		t.expect(first and second, "burst not allowed")
		t.expect(not lim(0), "over burst allowed")
		t.expect(lim(0.5), "refill not applied")
		t.expect(not lim(0.5), "refill too generous")
	end)

	t.test("kit: Odds", function()
		local w = { common = 70, rare = 25, epic = 5, never = 0 }
		local sum = 0
		for _, e in Odds.percentages(w) do
			sum += e.percent
		end
		t.expect(math.abs(sum - 100) < 1e-6, "percentages add up to " .. sum)
		t.expect(Odds.percentages(w)[1].key == "never", "not sorted rarest first")
		local rng = Random.new(7)
		local seen = {}
		for _ = 1, 3000 do
			local k = Odds.roll(w, rng)
			seen[k] = (seen[k] or 0) + 1
		end
		t.expect(seen.never == nil, "zero-weight item rolled")
		t.expect(seen.epic and seen.epic > 50 and seen.epic < 300, "epic rolled " .. tostring(seen.epic) .. "/3000")
		t.expect(Odds.format(5) == "5%" and Odds.format(12.5) == "12.5%" and Odds.format(0.001) == "<0.01%", "format")
	end)

	t.test("kit: catalog items are complete and created in this universe", function()
		for _, kind in { "passes", "products" } do
			for key, item in Catalog[kind] do
				t.expect(type(item.name) == "string" and #item.name >= 3, kind .. "." .. key .. ": name")
				t.expect(type(item.price) == "number" and item.price >= 1 and item.price == math.floor(item.price), kind .. "." .. key .. ": price")
				if t.options.expectProductIds then
					t.expect(Products.id(kind, key) ~= 0, ("%s.%s has no id in universe %d (sync-products didn't run, or its lock commit isn't in this build)"):format(kind, key, game.GameId))
				end
			end
		end
	end)

	t.test("kit: session lock", function()
		local store = Data.memoryStore()
		local defaults = { Coins = 0, Bag = {} }
		local a = Data.open(store, "k", defaults, "A", 1000)
		t.expect(a and a.data.Coins == 0, "new save not created from defaults")
		local b, err = Data.open(store, "k", defaults, "B", 1010)
		t.expect(b == nil and err == "locked", "second server got a locked save: " .. tostring(err))
		a.data.Coins = 5
		t.expect(Data.save(a, false, 1020), "save failed")
		b = Data.open(store, "k", defaults, "B", 1020 + Data.LOCK_TTL + 1)
		t.expect(b and b.data.Coins == 5, "stale lock not taken over, or data lost")
		local ok, why = Data.save(a, false, 2000)
		t.expect(not ok and why == "lost" and not a.alive, "old server kept writing after losing the lock")
		t.expect(Data.save(b, true), "release failed")
		local again = Data.open(store, "k", { Coins = 0, Bag = {}, Gems = 3 }, "C", 2001)
		t.expect(again and again.data.Coins == 5 and again.data.Gems == 3, "released save not reopened / new default missing")
	end)

	t.test("kit: a save in another format is never overwritten", function()
		local store = Data.memoryStore()
		store:UpdateAsync("odd", function()
			return 42
		end)
		local s, err = Data.open(store, "odd", { Coins = 0 }, "A")
		t.expect(s == nil and err ~= "locked", "foreign save was loaded")
		local kept
		store:UpdateAsync("odd", function(old)
			kept = old
			return nil
		end)
		t.expect(kept == 42, "foreign save was overwritten")
	end)

	t.test("kit: product receipts grant exactly once", function()
		local s = Data.open(Data.memoryStore(), "r", { Coins = 0 }, "A")
		t.expect(Shop.applyReceipt(s, "p1", function(d)
			d.Coins += 10
		end) == "granted", "first grant")
		t.expect(Shop.applyReceipt(s, "p1", function(d)
			d.Coins += 10
		end) == "duplicate", "duplicate receipt granted again")
		t.expect(s.data.Coins == 10, "coins " .. s.data.Coins)
		local result = Shop.applyReceipt(s, "p2", function(d)
			d.Coins += 1
			error("handler bug")
		end)
		t.expect(result == "error" and s.data.Coins == 10 and not table.find(s.receipts, "p2"), "failed grant changed the save")
	end)

	t.test("kit: DataStore round trip in this server", function()
		if game.GameId == 0 then
			t.info("DataStore round trip skipped (unpublished place)")
			return
		end
		local store = DataStoreService:GetDataStore("KitTest")
		local key = "t_" .. HttpService:GenerateGUID(false)
		local s, err = Data.open(store, key, { N = 0 }, "test-A")
		t.expect(s, "open failed: " .. tostring(err))
		s.data.N = 7
		t.expect(Data.save(s, true), "save failed")
		local s2 = Data.open(store, key, { N = 0 }, "test-B")
		t.expect(s2 and s2.data.N == 7, "value did not persist")
		Data.save(s2, true)
		store:RemoveAsync(key)
	end)

	t.test("kit: Data and Shop start", function()
		Data.start()
		Shop.start()
		local remotes = ReplicatedStorage.Kit:FindFirstChild("Remotes")
		t.expect(remotes and remotes:FindFirstChild("Kit.Buy") and remotes:FindFirstChild("Kit.Purchased"), "kit remotes missing")
	end)

	t.test("kit: Leaderboard keeps records and ranks them", function()
		local b = Leaderboard.board("KitTest", { store = "Leaderboard_KitTest_v1", size = 3, refresh = 30 })
		b:set(101, 50)
		b:set(102, 80.7)
		b:set(103, 10)
		b:set(101, 20) -- lower than the record: ignored
		b:set(104, 0 / 0) -- not a number: ignored
		t.expect(b.known[101] == 50, "a lower value replaced the record")
		t.expect(b.known[102] == 80, "values should be whole numbers")
		t.expect(b.known[104] == nil, "NaN was kept")
		if not b.ods then
			b:read()
			local top = b:top()
			t.expect(#top == 3 and top[1].userId == 102 and top[3].userId == 103, "in-memory ranking is wrong")
		end
	end)

end
