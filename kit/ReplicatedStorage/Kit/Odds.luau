--!strict
-- Odds: weighted random picks with the percentages to show players (GUIDELINES: paid random
-- items always show their odds). Use the same weights table on the server to roll and on the
-- client to display.
local Odds = {}

export type Weights = { [string]: number }

local function sortedKeys(weights: Weights): { string }
	local keys = {}
	for k, w in weights do
		assert(type(w) == "number" and w >= 0 and w == w, "Odds: weight for " .. k .. " must be a number >= 0")
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local function total(weights: Weights): number
	local sum = 0
	for _, w in weights do
		sum += w
	end
	assert(sum > 0, "Odds: weights add up to 0")
	return sum
end

-- server: pick a key. rng defaults to a fresh Random.
function Odds.roll(weights: Weights, rng: Random?): string
	local r = (rng or Random.new()):NextNumber() * total(weights)
	local keys = sortedKeys(weights)
	for _, k in keys do
		r -= weights[k]
		if r < 0 then
			return k
		end
	end
	-- floating-point edge: fall back to the last key with any weight
	for i = #keys, 1, -1 do
		if weights[keys[i]] > 0 then
			return keys[i]
		end
	end
	return keys[#keys]
end

-- client: { { key, percent } } from rarest to most common
function Odds.percentages(weights: Weights): { { key: string, percent: number } }
	local sum = total(weights)
	local out = {}
	for _, k in sortedKeys(weights) do
		table.insert(out, { key = k, percent = weights[k] / sum * 100 })
	end
	table.sort(out, function(a, b)
		if a.percent ~= b.percent then
			return a.percent < b.percent
		end
		return a.key < b.key
	end)
	return out
end

-- "12.5%", "0.1%", "<0.01%"
function Odds.format(percent: number): string
	if percent > 0 and percent < 0.01 then
		return "<0.01%"
	elseif math.abs(percent - math.floor(percent + 0.5)) < 0.005 then
		return ("%d%%"):format(math.floor(percent + 0.5))
	end
	return (("%.2f"):format(percent):gsub("0+$", ""):gsub("%.$", "")) .. "%"
end

return Odds
