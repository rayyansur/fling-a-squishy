--!nonstrict
-- UI audit: run with the Studio MCP `execute_luau` in the **Client** datamodel during a playtest,
-- with the screen you want to check open (HUD, then each panel and tab). The sync snippet installs
-- it as ReplicatedStorage.PipelineUIAudit, so the call is:
--     return require(game.ReplicatedStorage.PipelineUIAudit)()
-- It prints every problem a screenshot is easy to miss, and returns them as a string:
--
--   CLIPPED    a child (including its UIStroke, which is drawn OUTSIDE the frame, and a little
--              room for press/hover scale) pokes past a ScrollingFrame / ClipsDescendants parent.
--              The usual cause: cards placed at (0, 0) inside a scroll body. Fix: UIPadding on
--              the scroll body >= stroke + 3 px (kit: UI.scroll; games: their own inset helper).
--   OFFSCREEN  part of a visible element is outside its ScreenGui (cut off by the screen edge).
--   TIGHT      a bordered child (button) jammed against its bordered parent's edge: the two
--              outlines touch or overlap. Keep >= 12 px (1080p offsets) between them.
--   TEXT       a label whose text doesn't fit (TextFits = false) or is scaled below 9 px.
--
-- It checks the real window first, then EMULATES smaller screens: it sets every ScreenGui's own
-- UIScale so the layout sees a screen only `h` virtual pixels tall (700 ~ a phone in landscape),
-- waits for layout, checks again, and restores. Modals must refit when that UIScale changes
-- (listen to its Scale), or they'll be reported, which is the point.
--
-- Opt-outs, for things clipped or off-screen on purpose: set the attribute `AuditAllowClip` on a
-- clipping container (e.g. a radial cooldown's half-discs), `AuditAllowOffscreen` on an element,
-- or `AuditAllowTight` on a child that overlaps its parent's edge on purpose (a "!" badge).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EMULATE = { 700 } -- virtual screen heights to try after the real one
local SLACK = 2 -- px of room a stroked child needs beyond its stroke (press/hover scale)
local TIGHT = 4 -- px: a bordered child closer than this to its bordered parent's edge looks jammed
local MAX_REPORT = 60

local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local out = {}

local function path(inst: Instance): string
	return inst:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
end

local function visible(g: GuiObject): boolean
	local p: Instance? = g
	while p and not p:IsA("LayerCollector") do
		if p:IsA("GuiObject") and not p.Visible then
			return false
		end
		p = p.Parent
	end
	local gui = g:FindFirstAncestorWhichIsA("LayerCollector")
	return gui ~= nil and gui.Enabled and gui:IsA("ScreenGui")
end

local function strokeOf(g: GuiObject): number
	local s = g:FindFirstChildOfClass("UIStroke")
	if s and s.Enabled and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and s.Transparency < 1 then
		return s.Thickness
	end
	return 0
end

-- the nearest ancestor that clips, and the rect it shows (scrolling: the whole canvas vertically)
local function clipper(g: GuiObject): (GuiObject?, Vector2?, Vector2?)
	local p = g.Parent
	while p and p:IsA("GuiObject") do
		if p:IsA("ScrollingFrame") then
			local x0 = p.AbsolutePosition.X
			local y0 = p.AbsolutePosition.Y - p.CanvasPosition.Y
			return p, Vector2.new(x0, y0), Vector2.new(x0 + p.AbsoluteWindowSize.X, y0 + math.max(p.AbsoluteCanvasSize.Y, p.AbsoluteWindowSize.Y))
		elseif p.ClipsDescendants then
			return p, p.AbsolutePosition, p.AbsolutePosition + p.AbsoluteSize
		end
		p = p.Parent
	end
	return nil
end

local function check(label: string)
	local before = #out
	for _, gui in pg:GetChildren() do
		if not gui:IsA("ScreenGui") or not gui.Enabled then
			continue
		end
		local screenLo, screenHi = gui.AbsolutePosition, gui.AbsolutePosition + gui.AbsoluteSize
		for _, g in gui:GetDescendants() do
			if not g:IsA("GuiObject") or g.AbsoluteSize.X < 1 or not visible(g) then
				continue
			end
			if g.BackgroundTransparency >= 1 and strokeOf(g) == 0 and not g:IsA("TextLabel") and not g:IsA("TextButton") and not g:IsA("ImageLabel") and not g:IsA("ImageButton") then
				continue -- an invisible layout holder
			end
			local st = strokeOf(g)
			local lo = g.AbsolutePosition - Vector2.new(st, st)
			local hi = g.AbsolutePosition + g.AbsoluteSize + Vector2.new(st, st)
			local c, clo, chi = clipper(g)
			if c and not c:GetAttribute("AuditAllowClip") then
				local need = if st > 0 then SLACK else 0
				if lo.X < clo.X + need - 0.5 or lo.Y < clo.Y + need - 0.5 or hi.X > chi.X - need + 0.5 or hi.Y > chi.Y - need + 0.5 then
					table.insert(out, ("[%s] CLIPPED %s by %s (child %d,%d..%d,%d vs clip %d,%d..%d,%d)"):format(label, path(g), c.Name, lo.X, lo.Y, hi.X, hi.Y, clo.X, clo.Y, chi.X, chi.Y))
				end
			elseif not c and not g:GetAttribute("AuditAllowOffscreen") then
				if lo.X < screenLo.X - 0.5 or lo.Y < screenLo.Y - 0.5 or hi.X > screenHi.X + 0.5 or hi.Y > screenHi.Y + 0.5 then
					table.insert(out, ("[%s] OFFSCREEN %s (%d,%d..%d,%d, screen %dx%d)"):format(label, path(g), lo.X, lo.Y, hi.X, hi.Y, gui.AbsoluteSize.X, gui.AbsoluteSize.Y))
				end
			end
			-- a bordered child jammed against its bordered parent's edge (outlines touch or overlap)
			local parent = g.Parent
			if st > 0 and parent and parent:IsA("GuiObject") and strokeOf(parent) > 0 and not g:GetAttribute("AuditAllowTight") then
				local plo, phi = parent.AbsolutePosition, parent.AbsolutePosition + parent.AbsoluteSize
				local gap = math.min(lo.X - plo.X, lo.Y - plo.Y, phi.X - hi.X, phi.Y - hi.Y)
				local inside = lo.X >= plo.X - 40 and hi.X <= phi.X + 40 -- badges poking out on purpose are fine
				if gap < TIGHT and gap > -st * 4 and inside then
					table.insert(out, ("[%s] TIGHT %s is %.0f px from %s's edge"):format(label, path(g), gap, parent.Name))
				end
			end
			if (g:IsA("TextLabel") or g:IsA("TextButton")) and g.Text ~= "" and g.TextTransparency < 1 then
				if not g.TextFits then
					table.insert(out, ("[%s] TEXT doesn't fit: %s %q"):format(label, path(g), g.Text:sub(1, 40)))
				elseif g.TextBounds.Y > 0 and g.TextBounds.Y < 9 then
					table.insert(out, ("[%s] TEXT tiny (%d px): %s %q"):format(label, g.TextBounds.Y, path(g), g.Text:sub(1, 40)))
				end
			end
			if #out >= MAX_REPORT then
				return
			end
		end
	end
	if #out == before then
		table.insert(out, ("[%s] ok"):format(label))
	end
end

local function settle()
	for _ = 1, 3 do
		RunService.RenderStepped:Wait()
	end
end

local cam = workspace.CurrentCamera
check(("window %dx%d"):format(cam.ViewportSize.X, cam.ViewportSize.Y))

-- emulate smaller screens through each ScreenGui's own UIScale
local scales = {}
for _, gui in pg:GetChildren() do
	local s = gui:IsA("ScreenGui") and gui:FindFirstChildOfClass("UIScale")
	if s then
		scales[s] = s.Scale
	end
end
if next(scales) then
	for _, h in EMULATE do
		for s in scales do
			-- the layout (designed in 1080p offsets) now sees a screen only h px tall
			local gui = s.Parent :: ScreenGui
			s.Scale = gui.AbsoluteSize.Y / h
		end
		settle()
		check(("emulated %d px tall"):format(h))
	end
	for s, base in scales do
		s.Scale = base
	end
	settle()
end

local report = table.concat(out, "\n")
print(report)
return report
