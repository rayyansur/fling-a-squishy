--!strict
-- Zone bands + rarity odds (DESIGN 2.2, 4.3). Weights per rarity, in Rarities order.
local Zones = {}

Zones.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
Zones.RarePlus = 3 -- index of the first rarity boosted by bounce / Goo Rain luck
Zones.RarityColors = {
	Common = "#B8C4D6",
	Uncommon = "#4CD964",
	Rare = "#3EC5FF",
	Epic = "#9B5CFF",
	Legendary = "#FF8A3D",
	Mythic = "#FF2E88",
}

Zones.List = {
	{ name = "Gumdrop Meadow", sign = "GUMDROP MEADOW", min = 0, max = 50, color = "#7CF25A", odds = { 85, 15, 0, 0, 0, 0 } },
	{ name = "Taffy Hills", sign = "TAFFY HILLS", min = 50, max = 120, color = "#FFB3D9", odds = { 60, 32, 8, 0, 0, 0 } },
	{ name = "Lollipop Forest", sign = "LOLLIPOP FOREST", min = 120, max = 220, color = "#5ED8FF", odds = { 35, 40, 20, 5, 0, 0 } },
	{ name = "Soda Springs", sign = "SODA SPRINGS", min = 220, max = 360, color = "#B78CFF", odds = { 0, 35, 40, 20, 5, 0 } },
	{ name = "Sprinkle Peaks", sign = "SPRINKLE PEAKS", min = 360, max = 560, color = "#FFD23F", odds = { 0, 0, 40, 40, 18, 2 } },
	{ name = "Rainbow Rim", sign = "RAINBOW RIM", min = 560, max = 900, color = "#FFFFFF", odds = { 0, 0, 0, 45, 45, 10 } },
}

Zones.GooRainLuck = 2
Zones.GlitterChance = 0.01
Zones.GlitterMult = 3

return Zones
