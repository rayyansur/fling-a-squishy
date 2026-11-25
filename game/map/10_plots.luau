--!nocheck
-- 12 plots: shelf, slingshot, squeeze pad, name sign (DESIGN 2.1). The server assigns owners
-- (attributes OwnerUserId, PlotIndex); clients render squishies onto the shelf.
local Shared = require("./lib/Shared")
local Config = Shared("Config")
local M = Config.Map

-- slingshot geometry (matches art/models/slingshot.py): fork tips and the pouch rest
local TIP_X, TIP_Y = 2.2, 7.6
local POUCH_Y = M.FlingHeight

return function(B, ctx)
	local ws = ctx.workspace
	local plots = B.folder(ws, "Plots")
	local top = M.TerraceTop
	for i = 1, M.PlotCount do
		local x = M.plotX(i)
		local plot = B.model(plots, "Plot" .. i)
		plot:SetAttribute("PlotIndex", i)
		plot:SetAttribute("OwnerUserId", 0)
		local half = M.PlotSize / 2

		-- floor tile (slightly raised so it never z-fights the terrace)
		B.boxMM(plot, "Floor", x - half, top, M.PlotZ - half, x + half, top + 0.2, M.PlotZ + half, "#FFE0EF", "SmoothPlastic")
		B.boxMM(plot, "Border", x - half - 0.4, top, M.PlotZ - half - 0.4, x + half + 0.4, top + 0.12, M.PlotZ + half + 0.4, "#FF8FC4", "SmoothPlastic")

		-- shelf (back of the plot, facing the valley)
		local shelfCf = B.CF.new(x, top + 0.2, M.ShelfZ) * B.CF.Angles(0, math.pi, 0)
		local shelf = ctx.Assets:place(plot, "shelf_l1", shelfCf)
		shelf.Name = "Shelf"
		for _, d in shelf:GetDescendants() do
			if d.Name == "Pin" and d:IsA("BasePart") then
				d.Transparency = 1
				d.CanQuery = false
			end
		end
		-- shelf level visuals (DESIGN 4.6): each piece has a Level; the client shows the ones the
		-- plot's ShelfLevel has reached
		local decor = B.folder(plot, "LevelDecor")
		local lights = ctx.Assets:place(decor, "shelf_lights", shelfCf)
		lights.Name = "Lights"
		lights:SetAttribute("Level", 2)
		for _, side in { -1, 1 } do
			local pillar = ctx.Assets:place(decor, "lollipop_tree", B.CF.new(x + side * 11.5, top + 0.2, M.ShelfZ + 7), { scale = 0.8 })
			pillar.Name = "Pillar"
			pillar:SetAttribute("Level", 3)
		end
		local topper = ctx.Assets:place(decor, "star_topper", shelfCf)
		topper.Name = "StarTopper"
		topper:SetAttribute("Level", 4)
		local arch = ctx.Assets:place(decor, "rainbow_arch", B.CF.new(x, top + 0.2, M.ShelfZ - 3), { scale = 0.105 })
		arch.Name = "Arch"
		arch:SetAttribute("Level", 5)
		for _, d in decor:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			end
		end

		-- where squishies sit: tier anchors read by the client renderer
		local slots = B.part(plot, { name = "ShelfAnchor", size = B.V3.new(1, 1, 1), cf = B.CF.new(x, top + 0.2, M.ShelfZ), t = 1, cc = false, cq = false, ct = false })
		slots:SetAttribute("Tiers", 3)

		-- squeeze pad
		local pad = ctx.Assets:place(plot, "jelly_pad", B.CF.new(x, top + 0.2, M.ShelfZ + 9), { scale = 6 / 18, collide = true })
		pad.Name = "SqueezePad"
		for _, d in pad:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = B.hex("#FF8FC4")
			end
		end

		-- slingshot at the terrace front edge, facing +Z
		local slingCf = B.CF.new(x, top, M.SlingshotZ) * B.CF.Angles(0, math.pi, 0)
		local sling = ctx.Assets:place(plot, "slingshot", slingCf)
		sling.Name = "Slingshot"
		local anchor = B.part(plot, { name = "FlingAnchor", size = B.V3.new(0.4, 0.4, 0.4), cf = B.CF.new(x, top, M.SlingshotZ), t = 1, cc = false, cq = false, ct = false })
		local fp = B.I.new("Attachment")
		fp.Name = "FlingPoint"
		fp.CFrame = B.CF.new(0, POUCH_Y, 0) -- never .Position: Lune drops it (HANDBOOK 7)
		fp.Parent = anchor
		for _, side in { -1, 1 } do
			local tip = B.I.new("Attachment")
			tip.Name = if side < 0 then "TipL" else "TipR"
			tip.CFrame = B.CF.new(side * TIP_X, TIP_Y, 0)
			tip.Parent = anchor
		end
		-- pouch (moved by the owner's client while charging) + the two rubber bands
		local pouch = B.ball(plot, "Pouch", x, top + POUCH_Y, M.SlingshotZ, 1.3, "#C2286F", "SmoothPlastic", { cc = false, cq = false, ct = false })
		for _, side in { -1, 1 } do
			local a = B.I.new("Attachment")
			a.Name = if side < 0 then "BandL" else "BandR"
			a.CFrame = B.CF.new(side * 0.55, 0, 0)
			a.Parent = pouch
			local band = B.I.new("Beam")
			band.Name = if side < 0 then "BandL" else "BandR"
			band.Attachment0 = anchor:FindFirstChild(if side < 0 then "TipL" else "TipR")
			band.Attachment1 = a
			band.Width0, band.Width1 = 0.45, 0.45
			band.Color = B.R.ColorSequence.new(B.hex("#FF4FA3"))
			band.FaceCamera = true
			band.Segments = 1
			band.LightInfluence = 0.5
			band.Parent = pouch
		end

		-- name sign (server writes the text)
		local signPart = B.part(plot, { name = "SignAnchor", size = B.V3.new(1, 1, 1), cf = B.CF.new(x, top + 13, M.ShelfZ), t = 1, cc = false, cq = false, ct = false })
		local bb = B.I.new("BillboardGui")
		bb.Name = "NameSign"
		bb.Size = B.R.UDim2.fromScale(16, 5)
		bb.MaxDistance = 200
		bb.LightInfluence = 0
		bb.Parent = signPart
		local function label(name, y, h, text, font, color)
			local t = B.I.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.Position = B.R.UDim2.fromScale(0, y)
			t.Size = B.R.UDim2.fromScale(1, h)
			t.Text = text
			t.FontFace = B.R.Font.fromEnum(B.E.Font[font])
			t.TextColor3 = B.hex(color)
			t.TextScaled = true
			t.TextWrapped = true
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = B.hex("#2B1B4A")
			t.Parent = bb
		end
		label("Title", 0, 0.22, "", "FredokaOne", "#FFD23F")
		label("Owner", 0.22, 0.48, "Free plot", "FredokaOne", "#FFFFFF")
		label("Income", 0.7, 0.3, "", "GothamBlack", "#7CF25A")
	end
end
