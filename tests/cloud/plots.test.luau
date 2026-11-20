--!nonstrict
-- DESIGN 2.1 / 6.2: twelve plots, each with its slingshot, shelf and sign, assigned lowest-free.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local SSS = game:GetService("ServerScriptService")
	local Config = require(RS.Shared.Config)
	local Plots = require(SSS.Server.Plots)
	local M = Config.Map

	t.test("12 plots with the parts the game reads", function()
		local plots = workspace:FindFirstChild("Plots")
		t.expect(plots ~= nil, "no Plots folder")
		for i = 1, M.PlotCount do
			local p = plots:FindFirstChild("Plot" .. i)
			t.expect(p ~= nil, "missing Plot" .. i)
			t.expect(p:GetAttribute("PlotIndex") == i, "Plot" .. i .. " PlotIndex")
			local anchor = p:FindFirstChild("FlingAnchor")
			t.expect(anchor and anchor:FindFirstChild("FlingPoint") and anchor:FindFirstChild("TipL") and anchor:FindFirstChild("TipR"), "Plot" .. i .. " fling attachments")
			t.expect(p:FindFirstChild("Pouch") ~= nil, "Plot" .. i .. " pouch")
			t.expect(p:FindFirstChild("Shelf") ~= nil and p:FindFirstChild("ShelfAnchor") ~= nil, "Plot" .. i .. " shelf")
			t.expect(p:FindFirstChild("SqueezePad") ~= nil, "Plot" .. i .. " squeeze pad")
			local sign = p:FindFirstChild("SignAnchor")
			t.expect(sign and sign:FindFirstChild("NameSign", true), "Plot" .. i .. " sign")
		end
	end)

	t.test("fling points sit where the config says", function()
		for i = 1, M.PlotCount do
			local fp = Plots.flingPoint(i)
			local want = M.flingPoint(i)
			t.expect((fp - Vector3.new(want[1], want[2], want[3])).Magnitude < 0.5, ("Plot%d fling point %s"):format(i, tostring(fp)))
		end
	end)

	t.test("plots are assigned lowest free first", function()
		t.expect(Plots.lowestFree({}, 12) == 1, "empty -> 1")
		t.expect(Plots.lowestFree({ [1] = 1, [2] = 2, [4] = 4 }, 12) == 3, "gap -> 3")
		local full = {}
		for i = 1, 12 do
			full[i] = i
		end
		t.expect(Plots.lowestFree(full, 12) == nil, "full -> nil")
	end)
end
