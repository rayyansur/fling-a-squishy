--!strict
-- Rarity weights (DESIGN 4.3): zone odds x bounce luck x Goo Rain luck, renormalized to 100.
local Rarity = {}

-- returns { [rarityName] = percent } summing to 100
function Rarity.weights(Zones: any, zone: number, bounces: number, gooRain: boolean, luckPerBounce: number): { [string]: number }
	local odds = Zones.List[zone].odds
	local raw = {}
	local sum = 0
	for i, name in Zones.Rarities do
		local w = odds[i]
		if i >= Zones.RarePlus then
			w *= luckPerBounce ^ bounces
			if gooRain then
				w *= Zones.GooRainLuck
			end
		end
		raw[name] = w
		sum += w
	end
	local out = {}
	for name, w in raw do
		out[name] = w / sum * 100
	end
	return out
end

-- weighted pick from { [name] = weight } with r in [0, 1); zero weights never win
function Rarity.pick(weights: { [string]: number }, order: { string }, r: number): string
	local total = 0
	for _, name in order do
		total += weights[name] or 0
	end
	local x = r * total
	local last = order[1]
	for _, name in order do
		local w = weights[name] or 0
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

return Rarity
