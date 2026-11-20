--!nonstrict
-- PR 2 return hooks in a real server: shelf level decor on every plot (4.6), Goo Rain published
-- on schedule (4.10), offline income math (4.11), the hub leaderboard (2.4).
return function(t)
	local RS = game:GetService("ReplicatedStorage")
	local SSS = game:GetService("ServerScriptService")
	local Config = require(RS.Shared.Config)
	local Economy = require(SSS.Server.Economy)
	local Leaderboard = require(SSS.Server.Leaderboard)
	local Pr = Config.Progress

	t.test("every plot has shelf decor for levels 2-5", function()
		local plots = workspace:FindFirstChild("Plots")
		for i = 1, Config.Map.PlotCount do
			local decor = plots:FindFirstChild("Plot" .. i):FindFirstChild("LevelDecor")
			t.expect(decor ~= nil, "Plot" .. i .. " has no LevelDecor")
			local levels = {}
			for _, m in decor:GetChildren() do
				levels[m:GetAttribute("Level") or 0] = true
			end
			for lv = 2, 5 do
				t.expect(levels[lv], ("Plot%d: nothing for shelf level %d"):format(i, lv))
			end
		end
	end)

	t.test("goo rain window is published and 90 s long", function()
		t.waitFor(function()
			return RS:GetAttribute("GooRainStart") ~= nil
		end, 20)
		local s, f = RS:GetAttribute("GooRainStart"), RS:GetAttribute("GooRainEnd")
		t.expect(math.abs((f - s) - Pr.GooRain.Duration) < 0.5, "window length " .. tostring(f - s))
		local now = workspace:GetServerTimeNow()
		t.expect(s - now <= Pr.GooRain.First + 1 and f > now, "the next window is no more than 4 min away at boot")
	end)

	t.test("offline income: 50% of logout income, capped at 6 h, ignores short gaps", function()
		local now = 1e9
		local a = Economy.offline(nil :: any, { lastOnline = now - 3600, lastIncomePerSec = 10 }, now)
		t.expect(a == 18000, "1 h at 10/s pays 18000, got " .. a)
		local b = Economy.offline(nil :: any, { lastOnline = now - 10 * 3600, lastIncomePerSec = 10 }, now)
		t.expect(b == 108000, "10 h pays the 6 h cap, got " .. b)
		t.expect(Economy.offline(nil :: any, { lastOnline = now - 30, lastIncomePerSec = 10 }, now) == 0, "under a minute pays nothing")
		t.expect(Economy.offline(nil :: any, { lastOnline = 0, lastIncomePerSec = 10 }, now) == 0, "first join pays nothing")
	end)

	t.test("leaderboard board exists and lists without errors", function()
		local hub = workspace:FindFirstChild("Hub")
		t.expect(hub and hub:FindFirstChild("Leaderboard", true), "no leaderboard board")
		t.expect(type(Leaderboard.lines()) == "table", "lines()")
	end)
end
