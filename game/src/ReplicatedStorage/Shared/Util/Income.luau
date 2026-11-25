--!strict
-- Income per squishy (DESIGN 4.8) and the player's totals. Pure.
local Income = {}

export type Mults = { shelf: number, reSquish: number, pass: number, party: number }

function Income.mults(data: any, E: any, hasCoinsPass: boolean, party: boolean, passMult: number, partyMult: number): Mults
	return {
		shelf = E.ShelfLevels[data.shelfLevel or 1].mult,
		reSquish = 1 + E.ReSquish.incomePer * (data.reSquishes or 0),
		pass = if hasCoinsPass then passMult else 1,
		party = if party then partyMult else 1,
	}
end

-- one shelf entry { s, z, g, m }: g = Shiny, m = Big / Giant / Galactic (DESIGN 21)
function Income.of(entry: any, S: any, Z: any, m: Mults): number
	local sp = S.ById[entry.s]
	if not sp then
		return 0
	end
	local mod = entry.m and Z.ModifierById and Z.ModifierById[entry.m]
	return sp.income * S.SizeMult[entry.z or 1] * (if entry.g then Z.GlitterMult else 1) * (if mod then mod.mult else 1) * m.shelf * m.reSquish * m.pass * m.party
end

function Income.total(shelf: { any }, S: any, Z: any, m: Mults): number
	local sum = 0
	for _, e in shelf do
		sum += Income.of(e, S, Z, m)
	end
	return sum
end

return Income
