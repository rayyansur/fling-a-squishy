--!nonstrict
-- DESIGN 13: boot validation passes on the shipped config, and catches broken ones.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local ConfigCheck = require(RS.Shared.Util.ConfigCheck)

	t.test("shipped config passes validation", function()
		local problems = ConfigCheck.run(Config)
		t.expect(#problems == 0, table.concat(problems, "; "))
	end)

	t.test("validation catches bad odds and a stray pad", function()
		local zones = table.clone(Config.Zones)
		zones.List = table.clone(Config.Zones.List)
		zones.List[1] = table.clone(zones.List[1])
		zones.List[1].odds = { 80, 15, 0, 0, 0, 0 }
		local map = table.clone(Config.Map)
		map.JellyPads = table.clone(Config.Map.JellyPads)
		map.JellyPads[4] = { x = 0, z = 47, zone = 2 } -- straddles the 50 boundary
		local bad = table.clone(Config)
		bad.Zones, bad.Map = zones, map
		local problems = ConfigCheck.run(bad)
		local text = table.concat(problems, "; ")
		t.expect(text:find("odds add up to 95") ~= nil, "missed bad odds: " .. text)
		t.expect(text:find("not inside zone") ~= nil, "missed the stray pad: " .. text)
	end)

	t.test("24 squishies, 4 per rarity, 4 bodies", function()
		t.expect(#Config.Squishies.List == 24, "expected 24 squishies")
		for _, r in Config.Zones.Rarities do
			t.expect(#Config.Squishies.ByRarity[r] == 4, r .. " should have 4")
		end
	end)

	t.test("save defaults match the spec", function()
		local d = Config.Data.defaults
		t.expect(Config.Data.store == "FAS_PlayerData_v1", "store name")
		t.expect(d.coins == 0 and d.sp == 1 and d.goo == 1 and d.gloves == 1, "start values")
		t.expect(d.shelfLevel == 1 and d.slotUpgrades == 0 and d.autoMerge == true, "shelf defaults")
	end)
end
