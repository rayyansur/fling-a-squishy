--!nocheck
-- Hub behind the terrace: Goo Lab, Glove Stand, Re-Squish Machine, Squishydex Wall, Leaderboard
-- (DESIGN 2.4). Each prompt opens a panel; HUD buttons mirror all of them.
local Shared = require("./lib/Shared")
local Config = Shared("Config")
local M = Config.Map

return function(B, ctx)
	local hub = B.model(ctx.workspace, "Hub")
	local top = M.TerraceTop
	local H = M.Hub

	local function stall(name, model, pos, action, panel, tab, faceZ)
		local m = ctx.Assets:place(hub, model, B.CF.new(pos[1], top, pos[2]) * B.CF.Angles(0, if faceZ then 0 else math.pi, 0))
		m.Name = name
		local anchor = B.part(m, { name = "PromptAnchor", size = B.V3.new(1, 1, 1), cf = B.CF.new(pos[1], top + 3, pos[2] + 5), t = 1, cc = false, cq = false, ct = false })
		local pp = B.prompt(anchor, { name = "Open", action = action, object = name, dist = 12 })
		pp:SetAttribute("Panel", panel)
		if tab then
			pp:SetAttribute("Tab", tab)
		end
		return m
	end
	stall("Goo Lab", "goo_lab", H.GooLab, "Goo", "Upgrades", "Goo")
	stall("Glove Stand", "glove_stand", H.GloveStand, "Gloves", "Upgrades", "Gloves")
	stall("Re-Squish Machine", "resquish_machine", H.ReSquish, "Re-Squish", "ReSquish")

	-- boards: Squishydex wall and the leaderboard, framed candy boards facing the terrace (+Z)
	local function board(name, pos, title, color)
		local m = B.model(hub, name)
		local x, z = pos[1], pos[2]
		for _, sx in { -1, 1 } do
			B.vcyl(m, "Leg", x + sx * 8, top + 6, z, 1.4, 12, color)
		end
		local face = B.box(m, "Board", x, top + 9, z, 16, 10, 1, "#FFFFFF", "SmoothPlastic")
		B.box(m, "Frame", x, top + 9, z - 0.3, 17.2, 11.2, 0.8, color, "SmoothPlastic")
		B.box(m, "Header", x, top + 14.8, z + 0.2, 12, 2.4, 1.2, color, "SmoothPlastic")
		B.surface(face, "Back", { name = "Board", ppu = 40, lit = false, labels = {
			{ name = "Title", text = title, font = "FredokaOne", color = "#2B1B4A", pos = { 0.05, 0.02 }, size = { 0.9, 0.2 }, wrap = true },
			{ name = "Body", text = "", font = "GothamBold", color = "#2B1B4A", pos = { 0.06, 0.24 }, size = { 0.88, 0.72 }, wrap = true, align = "Left", valign = "Top" },
		} })
		local anchor = B.part(m, { name = "PromptAnchor", size = B.V3.new(1, 1, 1), cf = B.CF.new(x, top + 3, z + 4), t = 1, cc = false, cq = false, ct = false })
		return m, anchor
	end
	local _, dexAnchor = board("Squishydex Wall", H.Dex, "SQUISHYDEX", "#9B5CFF")
	B.prompt(dexAnchor, { name = "Open", action = "Squishydex", object = "Squishydex Wall", dist = 12 }):SetAttribute("Panel", "Dex")
	board("Leaderboard", H.Leaderboard, "TOP SQUISHERS", "#3EC5FF")
end
