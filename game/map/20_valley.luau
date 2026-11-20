--!nocheck
-- Squish Valley: six zone bands, signs, props, edges (DESIGN 2.2). Bands are drawn along Z from
-- the launch line; the server measures true distance from each plot's Fling Point.
local Shared = require("./lib/Shared")
local Config = Shared("Config")
local M, Z = Config.Map, Config.Zones

local PROPS = {
	{ model = "gumdrop_bush", count = 8, scale = { 1, 1.6 } },
	{ model = "taffy_hill", count = 6, scale = { 1, 1.5 } },
	{ model = "lollipop_tree", count = 9, scale = { 1, 1.6 } },
	{ model = "soda_geyser", count = 5, scale = { 1, 1.3 }, bubbles = true },
	{ model = "frosted_peak", count = 6, scale = { 1, 1.8 } },
	{ model = "cloud", count = 6, scale = { 1.5, 2.5 }, float = { 14, 30 } },
}
local RAINBOW = { "#FF4F6E", "#FF8A3D", "#FFD23F", "#7CF25A", "#3EC5FF", "#9B5CFF" }

return function(B, ctx)
	local ws = ctx.workspace
	local valley = B.model(ws, "Valley")
	local V = M.Valley
	local line = M.SlingshotZ
	local rand = B.rng(4242)

	-- ground bands
	for i, zone in Z.List do
		local z0 = math.max(V.z0, zone.min + line)
		local z1 = if i == #Z.List then V.z1 else zone.max + line
		local band = B.boxMM(valley, "Zone" .. i, V.x0, V.y - 4, z0, V.x1, V.y, z1, if i == 6 then "#FFF6FC" else zone.color, "SmoothPlastic")
		band:SetAttribute("Zone", i)
		-- sign anchor: the client draws the floating sign (with the odds button) here
		local sign = B.part(valley, { name = "ZoneSign" .. i, size = B.V3.new(1, 1, 1), cf = B.CF.new(0, 34, z0 + 6), t = 1, cc = false, cq = false, ct = false })
		sign:SetAttribute("Zone", i)
	end
	-- rainbow-striped far edge of the Rim
	for k, c in RAINBOW do
		B.boxMM(valley, "RimStripe", V.x0, V.y, V.z1 - 4 * (7 - k), V.x1, V.y + 0.1, V.z1 - 4 * (6 - k), c, "SmoothPlastic")
	end

	-- side + far edges: chunky taffy cliffs so the valley never ends in a void
	for _, side in { -1, 1 } do
		local x = side * (V.x1 + 10)
		local z = V.z0
		while z < V.z1 do
			local len = 40 + rand() * 30
			local h = 18 + rand() * 22
			B.box(valley, "Cliff", x, V.y + h / 2 - 4, math.min(z + len / 2, V.z1), 20 + rand() * 8, h, len, if (z // 40) % 2 == 0 then "#FFB3D9" else "#FF8FC4", "SmoothPlastic")
			z += len - 4
		end
	end
	for xx = V.x0 - 20, V.x1 + 20, 50 do
		local h = 30 + rand() * 30
		B.box(valley, "Cliff", xx, V.y + h / 2 - 4, V.z1 + 14, 54, h, 24, if (xx // 50) % 2 == 0 then "#FFB3D9" else "#FF8FC4", "SmoothPlastic")
	end

	-- props: fewer, bigger, never on a jelly pad or the centre of a plot's lane start
	local props = B.model(valley, "Props")
	local placed = {}
	local function free(x, z, r)
		for _, pad in M.JellyPads do
			if (x - pad.x) ^ 2 + (z - pad.z) ^ 2 < (M.PadRadius + r + 6) ^ 2 then
				return false
			end
		end
		for _, p in placed do
			if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < (r + p[3]) ^ 2 then
				return false
			end
		end
		return true
	end
	for zi, prop in PROPS do
		local zone = Z.List[zi]
		local z0 = math.max(V.z0 + 8, zone.min + line + 8)
		local z1 = (if zi == #Z.List then V.z1 - 30 else zone.max + line) - 8
		local n, tries = 0, 0
		while n < prop.count and tries < 400 do
			tries += 1
			local x = V.x0 + 14 + rand() * (V.x1 - V.x0 - 28)
			local z = z0 + rand() * (z1 - z0)
			local s = prop.scale[1] + rand() * (prop.scale[2] - prop.scale[1])
			local r = 8 * s
			if free(x, z, r) then
				n += 1
				table.insert(placed, { x, z, r })
				local y = V.y
				if prop.float then
					y += prop.float[1] + rand() * (prop.float[2] - prop.float[1])
				end
				local m = ctx.Assets:place(props, prop.model, B.CF.new(x, y, z) * B.CF.Angles(0, rand() * math.pi * 2, 0), { scale = s, collide = false })
				m:SetAttribute("Zone", zi)
				if prop.bubbles then
					local emitPart = B.part(m, { name = "Fizz", size = B.V3.new(2, 1, 2), cf = B.CF.new(x, y + 6 * s, z), t = 1, cc = false, cq = false, ct = false })
					B.particles(emitPart, { name = "Bubbles", color = "#E9DBFF", size0 = 0.4, size1 = 1.2, rate = 6, speed0 = 6, speed1 = 12, accel = 2, life0 = 1.5, life1 = 2.5, alpha = 0.3, emission = 0.3 })
				end
			end
		end
	end

	-- the giant rainbow arch at the Rim
	ctx.Assets:place(props, "rainbow_arch", B.CF.new(0, V.y, 820), { scale = 1, collide = false })
end
