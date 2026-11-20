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
