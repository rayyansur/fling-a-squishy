--!strict
-- Hub leaderboard (DESIGN 2.4): the top 10 in this server by Total Squishies Collected
-- (stats.caught), written onto the board's SurfaceGui every 5 s.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ServerScriptService.Kit.Data)

local Leaderboard = {}

local function body(): TextLabel?
	local hub = workspace:FindFirstChild("Hub")
	local board = hub and hub:FindFirstChild("Leaderboard", true)
	local face = board and board:FindFirstChild("Board")
	local gui = face and face:FindFirstChildWhichIsA("SurfaceGui")
	return gui and gui:FindFirstChild("Body", true) :: TextLabel?
end

function Leaderboard.lines(): { string }
	local rows = {}
	for _, p in Players:GetPlayers() do
		local d = Data.get(p)
		if d then
			table.insert(rows, { name = p.DisplayName, n = d.stats.caught })
		end
	end
	table.sort(rows, function(a, b)
		return a.n > b.n
	end)
	local out = {}
	for i = 1, math.min(10, #rows) do
		table.insert(out, ("%d. %s  —  %d"):format(i, rows[i].name, rows[i].n))
	end
	return out
end

function Leaderboard.start()
	task.spawn(function()
		while true do
			local label = body()
			if label then
				local lines = Leaderboard.lines()
				label.Text = if #lines > 0 then table.concat(lines, "\n") else "Fling to get on the board!"
			end
			task.wait(5)
		end
	end)
end

return Leaderboard
