--!strict
-- Draws every plot's shelf (DESIGN 2.1, 4.4, 4.5, 6.6): the owner's from ShelfUpdate (with
-- squeeze readiness), everyone else's from the plot's "Shelf" attribute, within 160 studs.
-- Idle wobble within 100 studs, squeeze squash, merge pops.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Kit.Net)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)
local JellyPads = require(script.Parent.JellyPads)
local SquishyModel = require(script.Parent.SquishyModel)
local Palette = require(ReplicatedStorage.Shared.Theme).Palette

local M, S = Config.Map, Config.Squishies
local UIC = Config.UI
local player = Players.LocalPlayer

local ShelfView = {}
ShelfView.entries = {} :: { any } -- own shelf: { uid, s, size, glitter, readyAt }

-- shelf geometry (matches art/models/shelf_l1.py): tier surfaces above the plot floor,
-- forward offset (+Z) per tier, gentle forward curve at the ends
ShelfView.TIER_Y = { 1.0, 3.4, 5.8, 8.2 }
ShelfView.TIER_Z = { 2.6, 1.2, -0.2, -1.6 }
ShelfView.HALF_WIDTH = 11
ShelfView.CURVE = 0.9

type Rig = { model: Model, parts: { { part: BasePart, size: Vector3, offset: CFrame } }, base: CFrame, phase: number, squashAt: number, hopAt: number, key: string }
type PlotView = { rigs: { [string]: Rig }, order: { string }, visible: boolean }

local views: { [number]: PlotView } = {}
local folder: Folder

local function rigOf(model: Model, key: string): Rig
	local base = model:GetPivot()
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, { part = d, size = d.Size, offset = base:ToObjectSpace(d.CFrame) })
		end
	end
	return { model = model, parts = parts, base = base, phase = math.random() * math.pi * 2, squashAt = -math.huge, hopAt = os.clock() + 6 + math.random() * 8, key = key }
end

local function place(r: Rig, cf: CFrame)
	r.base = cf
	for _, p in r.parts do
		p.part.CFrame = cf * p.offset
	end
end

local function apply(r: Rig, kx: number, ky: number, lift: number)
	local cf = r.base * CFrame.new(0, lift, 0)
	for _, p in r.parts do
		local o = p.offset
		p.part.Size = Vector3.new(p.size.X * kx, p.size.Y * ky, p.size.Z * kx)
		p.part.CFrame = cf * CFrame.new(o.X * kx, o.Y * ky, o.Z * kx) * (o - o.Position)
	end
end

-- slot positions (plot-local offsets from the shelf anchor) for a list of (species, size)
function ShelfView.layout(items: { { s: string, size: number } }, tiers: number): { Vector3 }
	local out = {}
	local rows: { { number } } = {}
	local widths: { number } = {}
	local row, used = 1, 0
	local maxW = ShelfView.HALF_WIDTH * 2
	for i, it in items do
		local w = SquishyModel.width(it.s, it.size) + 0.25
		if used + w > maxW and used > 0 then
			widths[row] = used
			row += 1
			used = 0
		end
		rows[row] = rows[row] or {}
		table.insert(rows[row], i)
		used += w
		widths[row] = used
	end
	for r, idxs in rows do
		local x = -widths[r] / 2
		for _, i in idxs do
			local it = items[i]
			local w = SquishyModel.width(it.s, it.size) + 0.25
			local cx = x + w / 2
			x += w
			local y, z
			if r <= tiers then
				y = ShelfView.TIER_Y[r]
				z = ShelfView.TIER_Z[r] + ShelfView.CURVE * (cx / ShelfView.HALF_WIDTH) ^ 2
			else
				-- overflow: rows on the plot floor in front of the shelf
				y = 0
				z = 5 + (r - tiers) * 3
			end
			out[i] = Vector3.new(cx, y, z)
		end
	end
	return out
end

local function anchorCf(plotIndex: number): CFrame
	local p = M.shelfPoint(plotIndex)
	return CFrame.new(p[1], p[2] + 0.2, p[3])
end

local function decode(str: string?): { { s: string, size: number, glitter: boolean } }
	local out = {}
	if not str or str == "" then
		return out
	end
	for item in string.gmatch(str, "[^;]+") do
		local s, z, g = string.match(item, "^([%w_]+):(%d):(%d)$")
		if s and S.ById[s] then
			table.insert(out, { s = s, size = tonumber(z) or 1, glitter = g == "1" })
		end
	end
	return out
end

-- rebuild one plot's models from a list; keys = uid (own) or index+species (others)
local function sync(plotIndex: number, items: { any }, keyOf: (any, number) -> string)
	local view = views[plotIndex]
	if not view then
		view = { rigs = {}, order = {}, visible = true }
		views[plotIndex] = view
	end
	local keep: { [string]: boolean } = {}
	local order = {}
	for i, it in items do
		local key = keyOf(it, i)
		keep[key] = true
		table.insert(order, key)
		local rig = view.rigs[key]
		if not rig then
			local m = SquishyModel.build(it.s, it.size, it.glitter)
			m.Parent = if view.visible then folder else nil
			view.rigs[key] = rigOf(m, key)
		end
	end
	for key, rig in view.rigs do
		if not keep[key] then
			rig.model:Destroy()
			view.rigs[key] = nil
		end
	end
	view.order = order
	local tiers = 3
	local slots = ShelfView.layout(items, tiers)
	local base = anchorCf(plotIndex)
	for i, key in order do
		local r = view.rigs[key]
		place(r, base * CFrame.new(slots[i]))
	end
end

local function myPlot(): number?
	return player:GetAttribute("Plot") :: number?
end

local function renderOthers()
	for _, plot in (workspace:WaitForChild("Plots")):GetChildren() do
		local i = plot:GetAttribute("PlotIndex") :: number?
		if i and i ~= myPlot() then
			local items = decode(plot:GetAttribute("Shelf") :: string?)
			sync(i, items, function(it, n)
				return ("%d:%s:%d:%s"):format(n, it.s, it.size, tostring(it.glitter))
			end)
		end
	end
end

local function readyCount(): (number, number)
	local now = workspace:GetServerTimeNow()
	local ready = 0
	for _, e in ShelfView.entries do
		if (e.readyAt or 0) <= now then
			ready += 1
		end
	end
	return ready, #ShelfView.entries
end

local function onUpdate(list: { any })
	ShelfView.entries = list
	local i = myPlot()
	if i then
		sync(i, list, function(it)
			return it.uid
		end)
	end
	Hud.setSqueeze(readyCount())
end

local function screenPoint(p: Vector3): Vector2
	local cam = workspace.CurrentCamera
	if not cam then
		return Vector2.zero
	end
	local v = cam:WorldToViewportPoint(p)
	return Vector2.new(v.X, v.Y)
end

local function plusPop(at: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = at
	anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 1.8)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local l = Candy.label(bb, "+" .. Format.abbrev(amount), { Font = Enum.Font.FredokaOne, TextColor3 = Palette.lemon })
	Candy.textStroke(l, 2)
	game:GetService("TweenService"):Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = at + Vector3.new(0, 4, 0) }):Play()
	game:GetService("Debris"):AddItem(anchor, 0.8)
end

local function onSqueezed(uids: { string }, total: number, _readyAt: number)
	local i = myPlot()
	local view = i and views[i]
	if not view or not i then
		return
	end
	JellyPads.squeeze(i)
	local per = if #uids > 0 then total / #uids else 0
	local sounds = 0
	local center = Vector3.zero
	for k, uid in uids do
		local r = view.rigs[uid]
		if r then
			r.squashAt = os.clock() + (k % 6) * 0.02
			center += r.base.Position
			if k <= 12 then
				plusPop(r.base.Position + Vector3.new(0, 3, 0), per)
			end
			if sounds < 6 then
				sounds += 1
				task.delay(sounds * 0.03, function()
					Sound.play("squish", 0.9 + math.random() * 0.2)
				end)
			end
		end
	end
	Sound.play("coin_burst")
	if #uids > 0 then
		center /= #uids
		Candy.flyCoins(screenPoint(center), Hud.coinTarget(), math.clamp(#uids, 3, 8))
	end
end

local function onMerged(uid: string, s: string, z: number, _g: boolean)
	local sp = S.ById[s]
	if not sp then
		return
	end
	Sound.play("merge")
	Candy.toast(("MERGE! %s %s"):format(S.SizeNames[z], sp.name), Palette.grape)
	task.defer(function()
		local i = myPlot()
		local r = i and views[i] and views[i].rigs[uid]
		if r then
			r.squashAt = os.clock()
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
			p.Position = r.base.Position + Vector3.new(0, 2, 0)
			p.Parent = folder
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(Palette.lemon)
			pe.Speed = NumberRange.new(6, 12)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Lifetime = NumberRange.new(0.4, 0.8)
			pe.Size = NumberSequence.new(0.6, 0)
			pe.Enabled = false
			pe.Parent = p
			pe:Emit(30)
			game:GetService("Debris"):AddItem(p, 1)
		end
	end)
end

function ShelfView.start()
	folder = Instance.new("Folder")
	folder.Name = "Shelves"
	folder.Parent = workspace

	Net.listen("ShelfUpdate", onUpdate)
	Net.listen("Squeezed", onSqueezed)
	Net.listen("Merged", onMerged)

	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		plot:GetAttributeChangedSignal("Shelf"):Connect(function()
			local i = plot:GetAttribute("PlotIndex") :: number?
			if i and i ~= myPlot() then
				local items = decode(plot:GetAttribute("Shelf") :: string?)
				sync(i, items, function(it, n)
					return ("%d:%s:%d:%s"):format(n, it.s, it.size, tostring(it.glitter))
				end)
			end
		end)
	end
	player:GetAttributeChangedSignal("Plot"):Connect(renderOthers)
	renderOthers()

	Hud.onSqueeze = function()
		local ready = readyCount()
		if ready == 0 then
			Sound.play("ui_error")
			return
		end
		Net.send("SqueezeRequest")
	end
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			Hud.onSqueeze()
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		local now = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local mine = myPlot()
		local low = player:GetAttribute("LowGraphics") == true
		for i, view in views do
			local d = (anchorCf(i).Position - camPos).Magnitude
			local visible = i == mine or d <= UIC.RenderOthersWithin
			if visible ~= view.visible then
				view.visible = visible
				for _, r in view.rigs do
					r.model.Parent = if visible then folder else nil
				end
			end
			local wobble = visible and d <= UIC.WobbleWithin and not (low and i ~= mine)
			if wobble then
				for _, r in view.rigs do
					local kx, ky, lift = 1, 1 + 0.04 * math.sin(now / 1.6 * math.pi * 2 + r.phase), 0
					local sq = now - r.squashAt
					if sq >= 0 and sq < 0.3 then
						local a = sq / 0.3
						local e = math.exp(-5 * a) * math.cos(a * math.pi * 2.5)
						kx, ky = 1 + 0.25 * e, 1 - 0.3 * e
					end
					local h = now - r.hopAt
					if h >= 0 and h < 0.35 then
						lift = 4 * (h / 0.35) * (1 - h / 0.35) * 0.8
					elseif h >= 0.35 then
						r.hopAt = now + 6 + math.random() * 8
					end
					apply(r, kx, ky, lift)
				end
			end
		end
		Hud.setSqueeze(readyCount())
	end)
end

return ShelfView
