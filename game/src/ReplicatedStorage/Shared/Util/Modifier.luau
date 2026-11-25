--!strict
-- Rare catch modifiers (DESIGN 21): Big / Giant / Galactic (Config.Zones.Modifiers) plus Shiny
-- (the `g` flag). Pure.
local Modifier = {}

-- modifier id for a roll r in [0, 1), or nil; bounces raise every chance
function Modifier.roll(Z: any, r: number, bounces: number): string?
	local luck = 1 + Z.ModifierBounceLuck * (bounces or 0)
	local acc = 0
	for _, m in Z.Modifiers do
		acc += m.chance * luck
		if r < acc then
			return m.id
		end
	end
	return nil
end

-- "" (the wire / save form of "none") and unknown ids are nil
function Modifier.clean(Z: any, m: string?): string?
	if m and Z.ModifierById[m] then
		return m
	end
	return nil
end

function Modifier.mult(Z: any, m: string?): number
	local d = m and Z.ModifierById[m]
	return if d then d.mult else 1
end

function Modifier.scale(Z: any, m: string?): number
	local d = m and Z.ModifierById[m]
	return if d then d.scale else 1
end

-- income multiplier of the whole look: modifier x Shiny
function Modifier.incomeMult(Z: any, g: boolean?, m: string?): number
	return Modifier.mult(Z, m) * (if g then Z.GlitterMult else 1)
end

-- "Giant Shiny Chonky Boba Bear"
function Modifier.title(Z: any, S: any, s: string, z: number?, g: boolean?, m: string?): string
	local sp = S.ById[s]
	local parts = {}
	local d = m and Z.ModifierById[m]
	if d then
		table.insert(parts, d.name)
	end
	if g then
		table.insert(parts, "Shiny")
	end
	if (z or 1) > 1 then
		table.insert(parts, S.SizeNames[z :: number])
	end
	table.insert(parts, if sp then sp.name else s)
	return table.concat(parts, " ")
end

-- how big a catch moment is: 0 none, 1 card (Rare/Epic, Big, Shiny), 2 full reveal
-- (Legendary/Mythic, Giant, Galactic)
function Modifier.moment(Z: any, rarity: string, g: boolean?, m: string?): number
	local ri = table.find(Z.Rarities, rarity) or 1
	if ri >= 5 or m == "giant" or m == "galactic" then
		return 2
	end
	if ri >= 3 or m ~= nil or g then
		return 1
	end
	return 0
end

return Modifier
