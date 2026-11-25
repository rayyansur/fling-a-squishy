--!strict
-- Re-Squish rules (DESIGN 4.9). Pure: the requirement check and the reset.
local ReSquish = {}

-- coins needed for the next Re-Squish
function ReSquish.cost(data: any, E: any): number
	return E.reSquishCost((data.reSquishes or 0) + 1)
end

function ReSquish.hasLegendary(shelf: { any }, S: any, rarities: { string }): boolean
	local rank = {}
	for i, r in rarities do
		rank[r] = i
	end
	for _, e in shelf do
		local sp = S.ById[e.s]
		if sp and (rank[sp.rarity] or 0) >= 5 then
			return true
		end
	end
	return false
end

-- (coins ok, legendary ok)
function ReSquish.check(data: any, E: any, S: any, rarities: { string }): (boolean, boolean)
	return data.coins >= ReSquish.cost(data, E), ReSquish.hasLegendary(data.shelf, S, rarities)
end

-- reset in place: everything 4.9 resets; dex, count, badges, passes, streak, stats, Auto-Merge stay
function ReSquish.apply(d: any)
	d.reSquishes = (d.reSquishes or 0) + 1
	d.coins = 0
	d.sp = 1
	d.goo = 1
	d.gloves = 1
	d.sling = 1
	d.shelf = {}
	d.inv = {}
	d.slotUpgrades = 0
	d.shelfLevel = 1
end

function ReSquish.incomeMult(n: number, E: any): number
	return 1 + E.ReSquish.incomePer * n
end

return ReSquish
