--!strict
-- Shelf rules (DESIGN 4.5, 4.6). Pure functions over the saved shelf array.
local ShelfLogic = {}

ShelfLogic.MAX_SIZE = 3

-- indices of entries matching species/size/shiny/modifier (m nil = no modifier)
function ShelfLogic.matching(shelf: { any }, s: string, z: number, g: boolean, m: string?): { number }
	local out = {}
	for i, e in shelf do
		if e.s == s and (e.z or 1) == z and (e.g == true) == g and e.m == m then
			table.insert(out, i)
		end
	end
	return out
end

function ShelfLogic.canMerge(shelf: { any }, s: string, z: number, g: boolean, m: string?): boolean
	return z < ShelfLogic.MAX_SIZE and #ShelfLogic.matching(shelf, s, z, g, m) >= 3
end

-- merges 3 into 1 of the next size; returns the new entry or nil. newUid() makes the id.
function ShelfLogic.merge(shelf: { any }, s: string, z: number, g: boolean, newUid: () -> string, m: string?): any?
	if not ShelfLogic.canMerge(shelf, s, z, g, m) then
		return nil
	end
	local idx = ShelfLogic.matching(shelf, s, z, g, m)
	-- remove the three (highest index first), put the merged one where the first was
	local at = idx[1]
	for k = 3, 1, -1 do
		table.remove(shelf, idx[k])
	end
	local merged = { uid = newUid(), s = s, z = z + 1, g = g, m = m }
	table.insert(shelf, math.min(at, #shelf + 1), merged)
	return merged
end

-- merge as long as possible starting from (s, z, g); returns the list of merged entries
function ShelfLogic.autoMerge(shelf: { any }, s: string, z: number, g: boolean, newUid: () -> string, m: string?): { any }
	local made = {}
	while true do
		local e = ShelfLogic.merge(shelf, s, z, g, newUid, m)
		if not e then
			break
		end
		table.insert(made, e)
		z += 1
	end
	return made
end

-- would adding (s, 1, g) fit? true if a free slot exists, or auto-merge would absorb it
function ShelfLogic.fits(shelf: { any }, slots: number, s: string, g: boolean, autoMerge: boolean, m: string?): boolean
	if #shelf < slots then
		return true
	end
	return autoMerge and #ShelfLogic.matching(shelf, s, 1, g, m) >= 2
end

-- index of the lowest-income entry (ties: the first)
function ShelfLogic.lowest(shelf: { any }, incomeOf: (any) -> number): number?
	local best, bestV = nil, math.huge
	for i, e in shelf do
		local v = incomeOf(e)
		if v < bestV then
			best, bestV = i, v
		end
	end
	return best
end

-- Equip Best: the `slots` highest earners of shelf + inventory go on the shelf, the rest to the
-- inventory. Squishies already on the shelf win ties and keep their order. Returns new lists.
function ShelfLogic.equipBest(shelf: { any }, inv: { any }, slots: number, incomeOf: (any) -> number): ({ any }, { any })
	type Ranked = { e: any, v: number, onShelf: boolean, i: number }
	local all: { Ranked } = {}
	for i, e in shelf do
		table.insert(all, { e = e, v = incomeOf(e), onShelf = true, i = i })
	end
	for i, e in inv do
		table.insert(all, { e = e, v = incomeOf(e), onShelf = false, i = i })
	end
	table.sort(all, function(a, b)
		if a.v ~= b.v then
			return a.v > b.v
		end
		if a.onShelf ~= b.onShelf then
			return a.onShelf
		end
		return a.i < b.i
	end)
	local keep: { [any]: boolean } = {}
	for k = 1, math.min(slots, #all) do
		keep[all[k].e] = true
	end
	local newShelf, newInv = {}, {}
	for _, e in shelf do
		table.insert(if keep[e] then newShelf else newInv, e)
	end
	for _, e in inv do
		table.insert(if keep[e] then newShelf else newInv, e)
	end
	return newShelf, newInv
end

function ShelfLogic.find(shelf: { any }, uid: string): number?
	for i, e in shelf do
		if e.uid == uid then
			return i
		end
	end
	return nil
end

return ShelfLogic
