--!nocheck
-- 18 Jelly Pads, 3 per zone, in Config.Map.JellyPads (DESIGN 2.3).
local Shared = require("./lib/Shared")
local Config = Shared("Config")
local M = Config.Map

return function(B, ctx)
	local folder = B.folder(ctx.workspace, "JellyPads")
	for i, p in M.JellyPads do
		local color = M.PadColors[(i - 1) % #M.PadColors + 1]
		local pad = ctx.Assets:place(folder, "jelly_pad", B.CF.new(p.x, M.Valley.y, p.z), { collide = false })
		pad.Name = "JellyPad" .. i
		pad:SetAttribute("PadIndex", i)
		pad:SetAttribute("Zone", p.zone)
		for _, d in pad:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = B.hex(color)
				d.CastShadow = true
			end
		end
	end
end
