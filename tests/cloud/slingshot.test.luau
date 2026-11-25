--!nonstrict
-- Slingshot tiers (DESIGN 20) and the slingshot rig in the built place.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local SSS = game:GetService("ServerScriptService")
	local Config = require(RS.Shared.Config)
	local Upgrades = require(SSS.Server.Upgrades)
	local E, M = Config.Economy, Config.Map

	t.test("slingshot tiers get pricier and stronger", function()
		t.expect(#E.Slingshots >= 4, "tiers")
		t.expect(E.Slingshots[1].cost == 0 and E.Slingshots[1].mult == 1, "starter is free and x1")
		for i = 2, #E.Slingshots do
			t.expect(E.Slingshots[i].cost > E.Slingshots[i - 1].cost, "cost rises at " .. i)
			t.expect(E.Slingshots[i].mult > E.Slingshots[i - 1].mult, "mult rises at " .. i)
		end
	end)

	t.test("only the next slingshot can be bought, at the config price", function()
		local data = { sling = 1, goo = 1, gloves = 1, slotUpgrades = 0, shelfLevel = 1 }
		local cost, field = Upgrades.price(data, "sling", 2)
		t.expect(cost == E.Slingshots[2].cost and field == "sling", "tier 2 price")
		t.expect(Upgrades.price(data, "sling", 3) == nil, "can't skip a tier")
		t.expect(Upgrades.price({ sling = #E.Slingshots }, "sling", #E.Slingshots + 1) == nil, "no tier past the last")
	end)

	t.test("every tier has a model template", function()
		local folder = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Slingshots")
		t.expect(folder ~= nil, "Assets.Slingshots")
		for i = 1, #E.Slingshots do
			t.expect(folder:FindFirstChild(tostring(i)) ~= nil, "template " .. i)
		end
	end)

	t.test("pouch and fork tips sit up on the slingshot (attachments kept their CFrame)", function()
		for i = 1, M.PlotCount do
			local anchor = workspace.Plots["Plot" .. i].FlingAnchor
			local fp = anchor.FlingPoint.WorldPosition
			t.expect(math.abs(fp.Y - (M.TerraceTop + M.FlingHeight)) < 0.05, ("Plot%d fling point at y=%.2f"):format(i, fp.Y))
			t.expect(anchor.TipL.WorldPosition.Y > M.TerraceTop + 7, ("Plot%d left tip at y=%.2f"):format(i, anchor.TipL.WorldPosition.Y))
			t.expect((anchor.TipL.WorldPosition - anchor.TipR.WorldPosition).Magnitude > 4, "tips apart on Plot" .. i)
		end
	end)
end
