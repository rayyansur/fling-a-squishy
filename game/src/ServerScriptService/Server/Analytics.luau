--!strict
-- AnalyticsService wrappers (DESIGN 12). Every call is pcall-wrapped; nothing here can error.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

Analytics.Funnel = {
	"Joined",
	"FirstFling",
	"FirstBounce",
	"FirstSquishyArrived",
	"FirstSqueeze",
	"FirstMerge",
	"FirstUpgrade",
	"TutorialDone",
}

local logged: { [Player]: { [number]: boolean } } = {}

function Analytics.funnel(player: Player, step: number)
	local mine = logged[player] or {}
	logged[player] = mine
	if mine[step] then
		return
	end
	mine[step] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, Analytics.Funnel[step])
	end)
end

function Analytics.source(player: Player, amount: number, balance: number, name: string)
	if amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, "Coins", math.floor(amount), math.floor(balance), Enum.AnalyticsEconomyTransactionType.Gameplay.Name, name)
	end)
end

function Analytics.sink(player: Player, amount: number, balance: number, name: string)
	if amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, "Coins", math.floor(amount), math.floor(balance), Enum.AnalyticsEconomyTransactionType.Shop.Name, name)
	end)
end

function Analytics.custom(player: Player, name: string, value: number)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value)
	end)
end

game:GetService("Players").PlayerRemoving:Connect(function(p)
	logged[p] = nil
end)

return Analytics
