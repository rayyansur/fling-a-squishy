--!strict
-- Return hooks (DESIGN 4.9-4.12): Goo Rain, offline income, the 7-day calendar, daily quests,
-- Re-Squish wording.
local P = {}

export type DailyReward = {
	kind: string, -- "coins" | "sp" | "squishy" | "roll"
	min: number?,
	minutes: number?,
	amount: number?,
	rarity: string?,
	odds: { [string]: number }?,
}

P.GooRain = {
	First = 240, -- seconds of server uptime before the first one
	Interval = 720,
	Duration = 90,
	Warning = 30,
	DistMult = 1.25,
	HopMult = 2,
	Tint = "#FFF0FA",
}

P.Offline = { Rate = 0.5, CapSeconds = 6 * 3600, MinSeconds = 60 }

-- one per calendar day; `minutes` of current income or `min` coins, whichever is more
P.Daily = {
	{ kind = "coins", min = 400, minutes = 5 },
	{ kind = "coins", min = 900, minutes = 10 },
	{ kind = "sp", amount = 60 },
	{ kind = "coins", min = 3000, minutes = 20 },
	{ kind = "squishy", rarity = "Rare" },
	{ kind = "coins", min = 8000, minutes = 45 },
	{ kind = "roll", odds = { Epic = 70, Legendary = 28, Mythic = 2 } },
} :: { DailyReward }

-- `event` is the progress event that counts toward it (server Progress module)
P.Quests = {
	{ id = "fling", text = "Fling %d times", goal = 150, event = "fling" },
	{ id = "perfect", text = "Land %d PERFECT flings", goal = 15, event = "perfect" },
	{ id = "triple", text = "Get a triple bounce", goal = 1, event = "triple" },
	{ id = "merge", text = "Merge %d times", goal = 5, event = "merge" },
	{ id = "squeeze", text = "Squeeze %d times", goal = 30, event = "squeeze" },
	{ id = "rare", text = "Catch %d Rare+ squishies", goal = 3, event = "rare" },
	{ id = "rain", text = "Catch a squishy during Goo Rain", goal = 1, event = "rain" },
}
P.QuestsPerDay = 3
P.QuestReward = { min = 1000, minutes = 15 }

P.ReSquishConfirm = "All your squishies get squished into the machine. Ready?"

return P
