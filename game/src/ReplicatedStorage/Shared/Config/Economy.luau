--!strict
-- Prices and multipliers (DESIGN 4.2, 4.6, 4.7, 4.9, 4.12).
-- REBALANCED (DESIGN 18): the spec's own numbers reached the Rim in ~2 min. Distance per sqrt(SP)
-- 22 -> 1.2, prices x20 (first goo/glove tier ~x3.4 so the tutorial's buy stays quick), slots
-- 20k x 2.4^k, Re-Squish 2.5B. Odds and squishy incomes unchanged. Check: tests/local balance.
local E = {}

E.Goo = {
	{ name = "Bubblegum Goo", cost = 0, mult = 1.00, color = "#FF4FA3" },
	{ name = "Lime Slime", cost = 2000, mult = 1.10, color = "#7CF25A" },
	{ name = "Blue Raspberry", cost = 100000, mult = 1.25, color = "#3EC5FF" },
	{ name = "Grape Gel", cost = 800000, mult = 1.40, color = "#9B5CFF" },
	{ name = "Lemon Fizz", cost = 5600000, mult = 1.60, color = "#FFD23F", fizz = true },
	{ name = "Rainbow Goo", cost = 36000000, mult = 1.85, color = "#FF4FA3", rainbow = true },
}

E.Gloves = {
	{ name = "Bare Hands", cost = 0, sp = 1 },
	{ name = "Gummy Gloves", cost = 1200, sp = 2, color = "#7CF25A" },
	{ name = "Taffy Gloves", cost = 80000, sp = 3, color = "#FF4FA3" },
	{ name = "Soda Gloves", cost = 1000000, sp = 5, color = "#3EC5FF" },
	{ name = "Sprinkle Gloves", cost = 12000000, sp = 8, color = "#FFD23F", sprinkles = true },
	{ name = "Rainbow Gloves", cost = 80000000, sp = 12, color = "#FF4FA3", rainbow = true },
}

E.ShelfLevels = {
	{ cost = 0, mult = 1.00, visual = "plain candy shelf" },
	{ cost = 40000, mult = 1.10, visual = "+ gumdrop lights" },
	{ cost = 600000, mult = 1.25, visual = "wider, lollipop pillars" },
	{ cost = 9000000, mult = 1.45, visual = "4 tiers + spinning star topper" },
	{ cost = 120000000, mult = 1.70, visual = "rainbow arch over the shelf, sparkles" },
}

E.Slots = { base = 20000, growth = 2.4, start = 8, step = 2, max = 40 }
function E.slotCost(k: number): number
	return math.floor(E.Slots.base * E.Slots.growth ^ k)
end
function E.slotCount(upgrades: number): number
	return math.min(E.Slots.max, E.Slots.start + upgrades * E.Slots.step)
end
E.MaxSlotUpgrades = (E.Slots.max - E.Slots.start) // E.Slots.step

-- distance formula (DESIGN 4.1)
E.DistBase = 25
E.DistPerRootSP = 1.2
E.ChargeFloor = 0.2 -- a weak throw really is weak
E.PerfectMult = 1.1 -- PERFECT goes past a full charge
E.PerfectSP = 2 -- PERFECT doubles the Sling Power gained

E.ReSquish = { base = 2.5e9, growth = 4, incomePer = 0.5, distPer = 0.10 }
function E.reSquishCost(n: number): number
	return E.ReSquish.base * E.ReSquish.growth ^ (n - 1)
end

return E
