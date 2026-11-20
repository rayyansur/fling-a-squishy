--!nocheck
-- Model templates the client clones: squishy bodies, accessories, goo blob, clouds
-- (ReplicatedStorage.Assets). Bodies carry the shared face (eyes, shine, blush, mouth).
local Shared = require("./lib/Shared")
local Config = Shared("Config")
local S = Config.Squishies

return function(B, ctx)
	local rs = ctx.game:GetService("ReplicatedStorage")
	local assets = B.folder(rs, "Assets")
	local bodies = B.folder(assets, "Bodies")
	for _, b in S.Bodies do
		ctx.Assets:place(bodies, "body_" .. b, B.CF.new(), { collide = false })
	end
	local accs = B.folder(assets, "Accessories")
	local seen = {}
	for _, s in S.List do
		if s.acc and not seen[s.acc] then
			seen[s.acc] = true
			ctx.Assets:place(accs, s.acc, B.CF.new(), { collide = false })
		end
	end
	ctx.Assets:place(assets, "goo_blob", B.CF.new(), { collide = false })
	-- every template: no collision, no queries (they're visuals)
	for _, d in assets:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
		end
	end
end
