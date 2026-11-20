--!strict
-- World layout (DESIGN 2). Pure data: the Lune map build and the game both read it.
-- +Z points into the valley; the launch line is Z = 0; the terrace top is Y = TerraceTop.
local Map = {}

Map.TerraceTop = 2
Map.Terrace = { x0 = -190, x1 = 190, z0 = -60, z1 = 0, color = "#FFC6E2", trim = "#FF4FA3" }
Map.Valley = { x0 = -240, x1 = 240, z0 = 0, z1 = 950, y = 0 }
Map.Spawn = { 0, 3, -52 }
Map.WallZ = 2 -- invisible wall keeping players on the terrace

-- 12 plots, 32 apart, centred on Z = -30
Map.PlotCount = 12
Map.PlotSize = 28
Map.PlotZ = -30
Map.SlingshotZ = -2
Map.FlingHeight = 6 -- the pouch, above the terrace
function Map.plotX(i: number): number
	return -176 + (i - 1) * 32
end
-- Fling Point of plot i as {x, y, z}
function Map.flingPoint(i: number): { number }
	return { Map.plotX(i), Map.TerraceTop + Map.FlingHeight, Map.SlingshotZ }
end
-- shelf centre (back of the plot), where squishies hop home to
Map.ShelfZ = -41
function Map.shelfPoint(i: number): { number }
	return { Map.plotX(i), Map.TerraceTop, Map.ShelfZ }
end

-- landing rules
Map.MinDistance = 8
Map.MaxDistance = 900
Map.LandXMin = -230
Map.LandXMax = 230

-- Jelly Pads: 3 per zone. Every plot has a zone-2..5 pad within its ±30° cone.
Map.PadRadius = 9
Map.PadHeight = 1 -- floats this far above the valley floor
Map.MaxBounces = 3
Map.BounceDistanceFactor = 0.5
Map.BounceApexFactor = 0.6
Map.BounceLuckPerBounce = 1.25
Map.PadColors = { "#FF4FA3", "#3EC5FF", "#7CF25A", "#FFD23F", "#9B5CFF", "#FF8A3D" }
Map.JellyPads = {
	-- zone 1 Gumdrop Meadow (0-50)
	{ x = -110, z = 28, zone = 1 },
	{ x = 10, z = 28, zone = 1 },
	{ x = 120, z = 28, zone = 1 },
	-- zone 2 Taffy Hills (50-120)
	{ x = -130, z = 95, zone = 2 },
	{ x = 0, z = 95, zone = 2 },
	{ x = 130, z = 95, zone = 2 },
	-- zone 3 Lollipop Forest (120-220)
	{ x = -120, z = 168, zone = 3 },
	{ x = 10, z = 168, zone = 3 },
	{ x = 135, z = 168, zone = 3 },
	-- zone 4 Soda Springs (220-360)
	{ x = -140, z = 288, zone = 4 },
	{ x = 0, z = 288, zone = 4 },
	{ x = 140, z = 288, zone = 4 },
	-- zone 5 Sprinkle Peaks (360-560)
	{ x = -110, z = 458, zone = 5 },
	{ x = 20, z = 458, zone = 5 },
	{ x = 150, z = 458, zone = 5 },
	-- zone 6 Rainbow Rim (560-900)
	{ x = -130, z = 728, zone = 6 },
	{ x = 0, z = 728, zone = 6 },
	{ x = 130, z = 728, zone = 6 },
}

-- Hub (DESIGN 2.4)
Map.Hub = {
	GooLab = { -45, -85 },
	GloveStand = { 45, -85 },
	ReSquish = { 0, -105 },
	Dex = { -100, -85 },
	Leaderboard = { 100, -85 },
}

return Map
