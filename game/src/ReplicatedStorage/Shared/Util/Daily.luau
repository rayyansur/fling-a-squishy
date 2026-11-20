--!strict
-- 7-day calendar + daily quests (DESIGN 4.12). Pure; days are UTC day numbers (os.time() // 86400).
local Daily = {}

function Daily.day(t: number): number
	return t // 86400
end

-- what claiming today would do: claimable, the calendar day it pays (1..7), the new streak
function Daily.status(daily: any, today: number): (boolean, number, number)
	local last = daily.lastClaimDay or 0
	if last >= today then
		return false, daily.cycleDay or 1, daily.streak or 0
	end
	if last == today - 1 and (daily.streak or 0) > 0 then
		return true, (daily.cycleDay or 0) % 7 + 1, (daily.streak or 0) + 1
	end
	return true, 1, 1 -- first claim, or a missed day resets
end

-- coins for a "coins" tile or a quest: max(min, minutes of current income)
function Daily.coins(reward: any, incomePerSec: number): number
	return math.max(reward.min, math.floor(reward.minutes * 60 * incomePerSec))
end

-- three distinct quest ids for this player and day (stable across rejoins)
function Daily.pickQuests(pool: { any }, count: number, today: number, userId: number): { string }
	local seed = (today * 7919 + userId % 1000003) % 2147483647
	local function nextInt(n: number): number
		seed = (seed * 48271) % 2147483647
		return seed % n + 1
	end
	local ids = {}
	for _, q in pool do
		table.insert(ids, q.id)
	end
	local out = {}
	for _ = 1, math.min(count, #ids) do
		local i = nextInt(#ids)
		table.insert(out, table.remove(ids, i) :: string)
	end
	return out
end

-- a fresh quest list when the day changed; returns true if it reset
function Daily.refreshQuests(quests: any, pool: { any }, count: number, today: number, userId: number): boolean
	if quests.day == today and #quests.list == count then
		return false
	end
	quests.day = today
	quests.list = {}
	for _, id in Daily.pickQuests(pool, count, today, userId) do
		table.insert(quests.list, { id = id, n = 0, claimed = false })
	end
	return true
end

function Daily.questDef(pool: { any }, id: string): any?
	for _, q in pool do
		if q.id == id then
			return q
		end
	end
	return nil
end

-- weighted pick from { [rarity] = weight }, r in [0, 1)
function Daily.rollRarity(odds: { [string]: number }, order: { string }, r: number): string
	local total = 0
	for _, name in order do
		total += odds[name] or 0
	end
	local x = r * total
	local last = order[1]
	for _, name in order do
		local w = odds[name] or 0
		if w > 0 then
			last = name
			if x < w then
				return name
			end
			x -= w
		end
	end
	return last
end

return Daily
