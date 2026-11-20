--!strict
-- Boot validation (DESIGN 13). Returns a list of problems (empty = fine). The server errors on
-- any; the map build (game/map/99_validate.luau) runs it too, so tools/check.sh fails early.
local ConfigCheck = {}

local function increasing(list: { any }, field: string, name: string, problems: { string })
	for i = 2, #list do
		if not (list[i][field] > list[i - 1][field]) then
			table.insert(problems, ("%s: %s of tier %d (%s) is not above tier %d (%s)"):format(name, field, i, tostring(list[i][field]), i - 1, tostring(list[i - 1][field])))
		end
	end
end

function ConfigCheck.run(Config: any): { string }
	local problems = {}
	local Z, S, E, M = Config.Zones, Config.Squishies, Config.Economy, Config.Map

	for i, zone in Z.List do
		local sum = 0
		for _, w in zone.odds do
			sum += w
		end
		if math.abs(sum - 100) > 1e-6 then
			table.insert(problems, ("zone %d (%s) odds add up to %s, not 100"):format(i, zone.name, tostring(sum)))
		end
		if #zone.odds ~= #Z.Rarities then
			table.insert(problems, ("zone %d has %d odds for %d rarities"):format(i, #zone.odds, #Z.Rarities))
		end
		if i > 1 and zone.min ~= Z.List[i - 1].max then
			table.insert(problems, ("zone %d starts at %d but zone %d ends at %d"):format(i, zone.min, i - 1, Z.List[i - 1].max))
		end
	end

	local seen = {}
	local perRarity = {}
	for _, s in S.List do
		if seen[s.id] then
			table.insert(problems, "duplicate squishy id " .. s.id)
		end
		seen[s.id] = true
		perRarity[s.rarity] = (perRarity[s.rarity] or 0) + 1
		if not table.find(S.Bodies, s.body) then
			table.insert(problems, s.id .. " has unknown body " .. tostring(s.body))
		end
	end
	for _, r in Z.Rarities do
		if perRarity[r] ~= 4 then
			table.insert(problems, ("rarity %s has %d species, expected 4"):format(r, perRarity[r] or 0))
		end
	end

	increasing(E.Goo, "cost", "Goo", problems)
	increasing(E.Goo, "mult", "Goo", problems)
	increasing(E.Gloves, "cost", "Gloves", problems)
	increasing(E.Gloves, "sp", "Gloves", problems)
	increasing(E.ShelfLevels, "cost", "Shelf level", problems)
	increasing(E.ShelfLevels, "mult", "Shelf level", problems)
	for k = 1, E.MaxSlotUpgrades - 1 do
		if not (E.slotCost(k) > E.slotCost(k - 1)) then
			table.insert(problems, "slot costs do not increase at upgrade " .. k)
		end
	end

	-- pads: inside the valley, inside their zone band (measured along Z from the launch line)
	local V = M.Valley
	local count = {}
	for i, pad in M.JellyPads do
		local r = M.PadRadius
		if pad.x - r < V.x0 or pad.x + r > V.x1 or pad.z - r < V.z0 or pad.z + r > V.z1 then
			table.insert(problems, ("jelly pad %d at (%d, %d) is outside the valley"):format(i, pad.x, pad.z))
		end
		local zone = Z.List[pad.zone]
		local d0, d1 = pad.z - r - M.SlingshotZ, pad.z + r - M.SlingshotZ
		if not zone or d0 < zone.min or d1 > zone.max then
			table.insert(problems, ("jelly pad %d (z %d) is not inside zone %s's band"):format(i, pad.z, tostring(pad.zone)))
		end
		count[pad.zone] = (count[pad.zone] or 0) + 1
	end
	for i = 1, #Z.List do
		if count[i] ~= 3 then
			table.insert(problems, ("zone %d has %d jelly pads, expected 3"):format(i, count[i] or 0))
		end
	end
	-- every plot has a zone-2 pad within the aim cone (the rigged first fling relies on it)
	for p = 1, M.PlotCount do
		local fp = M.flingPoint(p)
		local ok = false
		for _, pad in M.JellyPads do
			if pad.zone == 2 then
				local a = math.deg(math.abs(math.atan2(pad.x - fp[1], pad.z - fp[3])))
				if a <= Config.Game.AimClampDeg then
					ok = true
				end
			end
		end
		if not ok then
			table.insert(problems, ("plot %d has no zone-2 jelly pad within ±%d°"):format(p, Config.Game.AimClampDeg))
		end
	end
	return problems
end

return ConfigCheck
