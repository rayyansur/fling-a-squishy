--!nonstrict
-- World checks: spawn, kill floor, and the pieces the game's scripts look up by name.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)

	t.test("players have somewhere to spawn", function()
		t.expect(workspace:FindFirstChildWhichIsA("SpawnLocation", true) ~= nil, "no SpawnLocation in Workspace")
	end)
	t.test("nothing important sits below the kill floor", function()
		local low = 0
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.Position.Y < workspace.FallenPartsDestroyHeight + 10 then
				low += 1
			end
		end
		t.expect(low == 0, low .. " parts are below FallenPartsDestroyHeight")
	end)
	t.test("18 jelly pads in their zones", function()
		local folder = workspace:FindFirstChild("JellyPads")
		t.expect(folder ~= nil, "no JellyPads folder")
		for i, p in Config.Map.JellyPads do
			local m = folder:FindFirstChild("JellyPad" .. i)
			t.expect(m ~= nil, "missing JellyPad" .. i)
			t.expect(m:GetAttribute("PadIndex") == i and m:GetAttribute("Zone") == p.zone, "JellyPad" .. i .. " attributes")
			local pos = m:GetPivot().Position
			t.expect(math.abs(pos.X - p.x) < 0.5 and math.abs(pos.Z - p.z) < 0.5, "JellyPad" .. i .. " position")
		end
	end)
	t.test("six zone sign anchors", function()
		local valley = workspace:FindFirstChild("Valley")
		t.expect(valley ~= nil, "no Valley")
		for i = 1, #Config.Zones.List do
			t.expect(valley:FindFirstChild("ZoneSign" .. i) ~= nil, "missing ZoneSign" .. i)
		end
	end)
	t.test("hub prompts open real panels", function()
		local hub = workspace:FindFirstChild("Hub")
		t.expect(hub ~= nil, "no Hub")
		local panels = {}
		for _, d in hub:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				panels[d:GetAttribute("Panel")] = true
			end
		end
		for _, want in { "Upgrades", "ReSquish", "Dex" } do
			t.expect(panels[want], "no prompt opens " .. want)
		end
	end)
	t.test("squishy templates exist for every species", function()
		local assets = RS:FindFirstChild("Assets")
		t.expect(assets ~= nil, "no ReplicatedStorage.Assets")
		for _, b in Config.Squishies.Bodies do
			t.expect(assets.Bodies:FindFirstChild("body_" .. b) ~= nil, "missing body_" .. b)
		end
		for _, s in Config.Squishies.List do
			if s.acc then
				t.expect(assets.Accessories:FindFirstChild(s.acc) ~= nil, "missing " .. s.acc)
			end
		end
		t.expect(assets:FindFirstChild("goo_blob") ~= nil, "missing goo_blob")
	end)
end
