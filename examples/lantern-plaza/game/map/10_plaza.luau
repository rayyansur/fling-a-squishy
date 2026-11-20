--!nocheck
-- Sample map: a small plaza with a Blender-made lantern you can switch on and off.
-- Shows the three building blocks: parts from code, meshes from art/, and tags
-- that scripts look up at runtime.
return function(B, ctx)
	local ws = ctx.workspace
	local V3, CF = B.V3, B.CF
	local plaza = B.model(ws, "Plaza")

	B.box(plaza, "Ground", 0, -0.5, 0, 140, 1, 140, "#4b5a3a", "Grass")
	for x = -3, 3 do
		for z = -3, 3 do
			local shade = ((x + z) % 2 == 0) and "#a9a399" or "#9e978c"
			B.box(plaza, "Paver", x * 4, 0.05, z * 4, 3.9, 0.1, 3.9, shade, "Concrete")
		end
	end
	B.vcyl(plaza, "Rim", 0, 0.12, 0, 30, 0.14, "#6e6a64", "Concrete", { cc = false })

	-- the lantern comes from art/models/lantern.py once CI has uploaded it
	local lantern = ctx.Assets:place(plaza, "lantern", CF.new(0, 0.1, 0))
	lantern:AddTag("ToggleLamp")
	local glow = B.ball(lantern, "Glow", 0, 4.55, 0, 0.75, "#ffc86b", "Neon", { cc = false })
	B.light(glow, "PointLight", { color = "#ffc27a", brightness = 2, range = 20, shadows = true })
	local prompt = B.prompt(glow, { name = "TogglePrompt", action = "Toggle light", object = "Lantern", dist = 10 })

	local spawn = B.I.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = V3.new(6, 0.2, 6)
	spawn.CFrame = CF.new(0, 0.2, 18)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = ws
end
