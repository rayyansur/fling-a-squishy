--!nocheck
-- Launch Terrace + hub floor, spawn, map edges (DESIGN 2.1, 2.4).
local Shared = require("./lib/Shared")
local Config = Shared("Config")
local M = Config.Map

return function(B, ctx)
	local ws = ctx.workspace
	local world = B.model(ws, "Terrace")
	local top = M.TerraceTop
	local T = M.Terrace

	-- terrace slab (Z -60..0) and the hub floor behind it (Z -120..-60), one height
	B.boxMM(world, "TerraceFloor", T.x0, top - 6, T.z0, T.x1, top, T.z1, T.color, "SmoothPlastic")
	B.boxMM(world, "HubFloor", T.x0, top - 6, -120, T.x1, top, T.z0, "#FFD6E8", "SmoothPlastic")
	-- candy-brick trim along the valley edge: alternating pink / cream blocks on the face
	local x = T.x0
	local i = 0
	while x < T.x1 do
		local w = math.min(10, T.x1 - x)
		B.boxMM(world, "Trim", x, -1, T.z1 - 0.01, x + w, top + 0.6, T.z1 + 1.2, if i % 2 == 0 then T.trim else "#FFFFFF", "SmoothPlastic")
		x += w
		i += 1
	end
	-- hub walkway stripes leading from spawn to each stall
	B.boxMM(world, "HubPath", -6, top, -118, 6, top + 0.05, -60, "#FFB3D9", "SmoothPlastic", { cc = true })

	-- low candy fence around the hub and terrace sides + invisible walls
	local fence = B.model(world, "Fence")
	local function fenceRun(x0, z0, x1, z1)
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		local n = math.max(1, math.floor(len / 8))
		for k = 0, n do
			local a = k / n
			local px, pz = x0 + (x1 - x0) * a, z0 + (z1 - z0) * a
			B.vcyl(fence, "Post", px, top + 1.6, pz, 0.9, 3.2, if k % 2 == 0 then "#FF4FA3" else "#3EC5FF")
			B.ball(fence, "Cap", px, top + 3.4, pz, 1.3, "#FFFFFF")
		end
		B.beam(fence, "Rail", B.V3.new(x0, top + 2.4, z0), B.V3.new(x1, top + 2.4, z1), 0.5, 0.5, "#FFFFFF")
		-- invisible wall
		local mid = B.V3.new((x0 + x1) / 2, top + 15, (z0 + z1) / 2)
		local wall = B.beam(fence, "Wall", B.V3.new(x0, top + 15, z0), B.V3.new(x1, top + 15, z1), 1, 30, "#FFFFFF", nil, { t = 1, shadow = false })
		wall.CFrame = B.CF.lookAt(mid, B.V3.new(x1, top + 15, z1))
	end
	fenceRun(T.x0, -119, T.x1, -119)
	fenceRun(T.x0, -119, T.x0, 0)
	fenceRun(T.x1, -119, T.x1, 0)

	-- keep players on the terrace: invisible wall just past the valley edge
	B.boxMM(world, "ValleyWall", -240, top, M.WallZ - 0.5, 240, top + 40, M.WallZ + 0.5, "#FFFFFF", nil, { t = 1, shadow = false })

	local s = M.Spawn
	local spawn = B.I.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = B.V3.new(10, 0.4, 10)
	spawn.CFrame = B.CF.new(s[1], top + 0.2, s[3])
	spawn.Color = B.hex("#FF4FA3")
	spawn.Material = B.E.Material.SmoothPlastic
	spawn.TopSurface = B.E.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = ws
	local decal = spawn:FindFirstChildWhichIsA("Decal")
	if decal then
		decal:Destroy()
	end
end
