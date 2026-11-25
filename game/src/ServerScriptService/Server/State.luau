--!strict
-- Per-player runtime state that isn't saved: plot, hops in flight, squeeze cooldowns, the Shelf
-- Full queue. Cleared on leave.
local Players = game:GetService("Players")

export type Pending = { entry: any, deadline: number }
export type PlayerState = {
	plot: number?,
	hopping: number,
	lastFling: number,
	readyAt: { [string]: number }, -- uid -> server time the squishy can be squeezed again
	fullQueue: { Pending },
	incomePerSec: number,
	flingsThisSession: number,
	chargeStart: number?, -- os.clock() of the last ChargeBegin
	streak: number, -- PERFECT throws in a row (Config.Game.PerfectStreakMax cap)
	incomeAcc: number, -- fractional coins carried between income ticks
	epoch: number, -- bumped by Re-Squish: squishies still hopping from before it are dropped
}

local State = {}
local states: { [Player]: PlayerState } = {}

function State.get(player: Player): PlayerState
	local s = states[player]
	if not s then
		s = {
			plot = nil,
			hopping = 0,
			lastFling = -math.huge,
			readyAt = {},
			fullQueue = {},
			incomePerSec = 0,
			flingsThisSession = 0,
			chargeStart = nil,
			streak = 0,
			incomeAcc = 0,
			epoch = 0,
		}
		states[player] = s
	end
	return s
end

function State.drop(player: Player)
	states[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	task.defer(State.drop, player)
end)

return State
