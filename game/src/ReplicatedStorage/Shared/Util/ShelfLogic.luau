--!strict
-- Shelf rules (DESIGN 4.5, 4.6). Pure functions over the saved shelf array.
local ShelfLogic = {}

ShelfLogic.MAX_SIZE = 3

-- indices of entries matching species/size/glitter
function ShelfLogic.matching(shelf: { any }, s: string, z: number, g: boolean): { number }
	local out = {}
	for i, e in shelf do
		if e.s == s and (e.z or 1) == z and (e.g == true) == g then
			table.insert(out, i)
		end
	end
	return out
end

function ShelfLogic.canMerge(shelf: { any }, s: string, z: number, g: boolean): boolean
	return z < ShelfLogic.MAX_SIZE and #ShelfLogic.matching(shelf, s, z, g) >= 3
end

-- merges 3 into 1 of the next size; returns the new entry or nil. newUid() makes the id.
function ShelfLogic.merge(shelf: { any }, s: string, z: number, g: boolean, newUid: () -> string): any?
	if not ShelfLogic.canMerge(shelf, s, z, g) then
		return nil
	end
	local idx = ShelfLogic.matching(shelf, s, z, g)
	-- remove the three (highest index first), put the merged one where the first was
	local at = idx[1]
	for k = 3, 1, -1 do
		table.remove(shelf, idx[k])
	end
	local merged = { uid = newUid(), s = s, z = z + 1, g = g }
	table.insert(shelf, math.min(at, #shelf + 1), merged)
	return merged
end

-- merge as long as possible starting from (s, z, g); returns the list of merged entries
function ShelfLogic.autoMerge(shelf: { any }, s: string, z: number, g: boolean, newUid: () -> string): { any }
	local made = {}
	while true do
		local m = ShelfLogic.merge(shelf, s, z, g, newUid)
		if not m then
			break
		end
		table.insert(made, m)
		z += 1
	end
	return made
end

-- would adding (s, 1, g) fit? true if a free slot exists, or auto-merge would absorb it
function ShelfLogic.fits(shelf: { any }, slots: number, s: string, g: boolean, autoMerge: boolean): boolean
	if #shelf < slots then
		return true
	end
	return autoMerge and #ShelfLogic.matching(shelf, s, 1, g) >= 2
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

function ShelfLogic.find(shelf: { any }, uid: string): number?
	for i, e in shelf do
		if e.uid == uid then
			return i
		end
	end
	return nil
end

return ShelfLogic
