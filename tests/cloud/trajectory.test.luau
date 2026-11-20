--!nonstrict
-- DESIGN 4.1 + 2.3: distance formula, bounces and clamps.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local T = require(RS.Shared.Util.Trajectory)
	local E, M, G = Config.Economy, Config.Map, Config.Game
	local rules = T.rulesFrom(M)

	t.test("reference distances (Bubblegum, perfect, no bounce; rebalanced DESIGN 18)", function()
		local want = { [1] = 26.2, [25] = 31, [100] = 37, [400] = 49, [10000] = 145 }
		for sp, d in want do
			local curve = T.chargeCurve(1, G.SweetSpot, E.ChargeFloor)
			local got = T.power(sp, 1, 0, false, E) * curve
			t.expect(math.abs(got - d) < 1, ("SP %d: %0.1f, expected %0.1f"):format(sp, got, d))
		end
	end)

	t.test("charge curve: floor, linear, sweet spot is PERFECT", function()
		local c0 = T.chargeCurve(0, 0.88, 0.35)
		local c5, p5 = T.chargeCurve(0.5, 0.88, 0.35)
		local c9, p9 = T.chargeCurve(0.9, 0.88, 0.35)
		t.expect(math.abs(c0 - 0.35) < 1e-9, "floor")
		t.expect(math.abs(c5 - 0.675) < 1e-9 and not p5, "half charge")
		t.expect(c9 == 1 and p9, "sweet spot")
	end)

	t.test("no pad hit: one segment", function()
		local start = Vector3.new(0, 8, -2)
		local path = T.compute(start, T.direction(0), 40, {}, rules)
		t.expect(#path.segments == 1 and path.bounces == 0, "one segment")
		t.expect(math.abs(path.distance - 40) < 0.01, "distance " .. path.distance)
		t.expect(math.abs(path.segments[1].apex - (8 + 40 * 0.15)) < 1e-6, "first apex")
		t.expect(math.abs(path.segments[1].time - (0.35 + 40 / 600)) < 1e-6, "flight time")
	end)

	t.test("bounces chain at 50% up to 3", function()
		local start = Vector3.new(0, 8, -2)
		-- pads right where each segment lands: 100, +50, +25, +12.5
		local pads = {
			{ x = 0, z = 98 },
			{ x = 0, z = 148 },
			{ x = 0, z = 173 },
			{ x = 0, z = 185.5 },
		}
		local path = T.compute(start, T.direction(0), 100, pads, rules)
		t.expect(path.bounces == 3, "bounces " .. path.bounces)
		t.expect(#path.segments == 4, "segments " .. #path.segments)
		t.expect(math.abs(path.segments[2].length - 50) < 0.01, "2nd = 50%")
		t.expect(math.abs(path.segments[3].length - 25) < 0.01, "3rd = 25%")
		t.expect(math.abs(path.segments[4].apex - path.segments[1].apex * 0.6 ^ 3) < 1e-6, "apex shrinks 60%")
		t.expect(path.segments[4].pad == nil, "4th segment can't bounce")
		t.expect(math.abs(path.distance - 187.5) < 0.01, "total " .. path.distance)
	end)

	t.test("total distance clamps to 900 and landing X to ±230", function()
		local start = Vector3.new(0, 8, -2)
		local far = T.compute(start, T.direction(0), 5000, {}, rules)
		t.expect(math.abs(far.distance - 900) < 0.01, "clamp 900: " .. far.distance)
		local side = T.compute(Vector3.new(176, 8, -2), T.direction(30), 400, {}, rules)
		t.expect(side.final.X <= 230 + 1e-6, "x clamp " .. side.final.X)
		local short = T.compute(start, T.direction(0), 2, {}, rules)
		t.expect(short.distance >= 8 - 1e-6, "min 8")
	end)

	t.test("every plot's rigged first fling hits a zone-2 pad and bounces once", function()
		for p = 1, M.PlotCount do
			local fp = M.flingPoint(p)
			local start = Vector3.new(fp[1], fp[2], fp[3])
			local idx = T.lanePad(start, M.JellyPads, 2)
			t.expect(idx ~= nil, "plot " .. p .. " has no zone-2 pad")
			local path = T.rigged(start, M.JellyPads, idx, rules)
			t.expect(path.bounces == 1 and #path.segments == 2, "one bounce")
			t.expect(path.segments[1].pad == idx, "lands on the pad")
		end
	end)

	t.test("zoneOf bands", function()
		local Z = Config.Zones.List
		t.expect(T.zoneOf(10, Z) == 1 and T.zoneOf(50, Z) == 2 and T.zoneOf(119, Z) == 2, "1-2")
		t.expect(T.zoneOf(560, Z) == 6 and T.zoneOf(900, Z) == 6, "6")
	end)
end
