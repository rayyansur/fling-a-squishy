--!nocheck
-- Starting ground + spawn. Replace with the game's real map.
return function(B, ctx)
	local ws = ctx.workspace
	local base = B.model(ws, "Base")
	B.box(base, "Ground", 0, -0.5, 0, 200, 1, 200, "#5b7a45", "Grass")

	local spawn = B.I.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = B.V3.new(8, 0.2, 8)
	spawn.CFrame = B.CF.new(0, 0.1, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = ws
end
