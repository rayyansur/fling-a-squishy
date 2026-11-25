--!nonstrict
-- Throw feel (DESIGN 19): charging beats tapping, the PERFECT window is fair, streaks and the
-- server's charge check.
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local T = require(RS.Shared.Util.Trajectory)
	local G, E = Config.Game, Config.Economy

	-- seconds the meter spends at or above the sweet spot on its way up and back down
	local function perfectWindow(): number
		return (1 - G.SweetSpot) * G.ChargeCycle
	end

	t.test("the PERFECT window is fair and reachable after the minimum hold", function()
		local w = perfectWindow()
		t.expect(w >= 0.18 and w <= 0.4, ("window %0.2f s"):format(w))
		local firstPerfect = G.SweetSpot * G.ChargeCycle / 2
		t.expect(firstPerfect > G.MinHold + 0.2, "the sweet spot comes well after the minimum hold")
		t.expect(T.chargeAt(firstPerfect + 0.01, G.ChargeCycle) >= G.SweetSpot, "chargeAt reaches the sweet spot")
	end)

	t.test("charging pays more than tapping (Sling Power per second and distance)", function()
		-- tapper: shortest legal hold, then the reload
		local tapCharge = T.chargeAt(G.MinHold, G.ChargeCycle)
		local tapCurve = T.chargeCurve(tapCharge, G.SweetSpot, E.ChargeFloor, E.PerfectMult)
		local tapPeriod = G.MinHold + G.FlingCooldown
		-- charger: releases in the middle of the window on the way up
		local perfHold = (G.SweetSpot + 1) / 2 * G.ChargeCycle / 2
		local perfCurve, perfect = T.chargeCurve(T.chargeAt(perfHold, G.ChargeCycle), G.SweetSpot, E.ChargeFloor, E.PerfectMult)
		t.expect(perfect, "mid-window release is PERFECT")
		local perfPeriod = perfHold + G.FlingCooldown
		local tapSP = 1 / tapPeriod
		local perfSP = E.PerfectSP / perfPeriod
		t.expect(perfSP > tapSP * 1.15, ("SP/s perfect %0.2f vs tap %0.2f"):format(perfSP, tapSP))
		t.expect(perfCurve > tapCurve * 2.2, ("distance perfect %0.2f vs tap %0.2f"):format(perfCurve, tapCurve))
	end)

	t.test("PERFECT goes past a full charge, and the streak adds distance up to the cap", function()
		local full = T.chargeCurve(G.SweetSpot - 0.001, G.SweetSpot, E.ChargeFloor, E.PerfectMult)
		local perf, p = T.chargeCurve(1, G.SweetSpot, E.ChargeFloor, E.PerfectMult)
		t.expect(p and perf > full, "PERFECT > the best non-perfect throw")
		t.expect(T.streakMult(1, G.PerfectStreakDist) == 1, "first PERFECT has no streak bonus")
		t.expect(math.abs(T.streakMult(3, 0.05) - 1.1) < 1e-9, "streak 3 = +10%")
		local cap = T.streakMult(G.PerfectStreakMax, G.PerfectStreakDist)
		t.expect(cap <= 1.25 + 1e-9, "streak bonus stays modest: " .. cap)
	end)

	t.test("server charge check: a claimed PERFECT after a short hold is replaced", function()
		local slack = 0.12
		local got = T.verifyCharge(1, G.MinHold, G.ChargeCycle, slack)
		t.expect(got < G.SweetSpot, "short hold can't claim PERFECT, got " .. got)
		local hold = G.ChargeCycle / 2
		local honest = T.chargeAt(hold, G.ChargeCycle)
		t.expect(T.verifyCharge(honest, hold, G.ChargeCycle, slack) == honest, "an honest claim is kept")
	end)

	t.test("Auto-Throw stays below PERFECT and under the reload", function()
		local Mo = Config.Monetization
		t.expect(Mo.AutoFlingCharge < G.SweetSpot, "auto charge is never PERFECT")
		t.expect(Mo.AutoFlingInterval >= G.FlingCooldown, "auto interval respects the reload")
	end)
end
