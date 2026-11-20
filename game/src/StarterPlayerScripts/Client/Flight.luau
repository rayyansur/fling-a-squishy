--!strict
-- Renders every fling (DESIGN 3.5-3.8): the goo blob along the server's segments with BOING!
-- bounces, the splat, the squishy popping out, and its hop home. All timing is server time.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local T = require(ReplicatedStorage.Shared.Util.Trajectory)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Kit.Net)
local Candy = require(script.Parent.Candy)
local Sound = require(script.Parent.Sound)
local JellyPads = require(script.Parent.JellyPads)
local SquishyModel = require(script.Parent.SquishyModel)
local Palette = require(ReplicatedStorage.Shared.Theme).Palette

local G, M, E, S, Z = Config.Game, Config.Map, Config.Economy, Config.Squishies, Config.Zones
local player = Players.LocalPlayer
local MAX_GOO, MAX_HOP = 72, 72

local Flight = {}

type Goo = { blob: Model, segs: { any }, starts: { number }, t0: number, total: number, owner: number, seg: number, color: Color3, rainbow: boolean, perfect: boolean, bounces: number }
type Hop = { model: Model?, from: Vector3, to: Vector3, landAt: number, arriveAt: number, owner: number, s: string, g: boolean, popped: boolean, hops: number, lastHop: number, size: number }

local goos: { Goo } = {}
local hops: { Hop } = {}
local folder: Folder
local blobTemplate: Model?

local function now(): number
	return workspace:GetServerTimeNow()
end

local function gooColor(tier: number): Color3
	return Color3.fromHex(E.Goo[tier] and E.Goo[tier].color or "#FF4FA3")
end

local function makeBlob(color: Color3): Model
	local m: Model
	if blobTemplate then
		m = blobTemplate:Clone()
	else
		m = Instance.new("Model")
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2, 2, 2)
		p.Parent = m
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d.Name ~= "Shine" then
				d.Color = color
			end
			if d.Name == "Pin" then
				d:Destroy()
			end
		end
	end
	m.Parent = folder
	return m
end

local function pop(at: Vector3, text: string, color: Color3, size: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = at
	anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10 * (size or 1), 3.5 * (size or 1))
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = anchor
	local l = Candy.label(bb, text, { Font = Enum.Font.FredokaOne, TextColor3 = color })
	Candy.textStroke(l, 3)
	local s = Instance.new("UIScale")
	s.Scale = 0.2
	s.Parent = l
	TweenService:Create(s, Candy.POP, { Scale = 1 }):Play()
	TweenService:Create(anchor, TweenInfo.new(0.6), { Position = at + Vector3.new(0, 3, 0) }):Play()
	Debris:AddItem(anchor, 0.6)
end

local function splat(at: Vector3, color: Color3)
	local d = Instance.new("Part")
	d.Shape = Enum.PartType.Cylinder
	d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
	d.Size = Vector3.new(0.12, 1, 1)
	d.CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	d.Color = color
	d.Material = Enum.Material.SmoothPlastic
	d.Parent = folder
	TweenService:Create(d, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = Vector3.new(0.12, 6, 6) }):Play()
	task.delay(1.2, function()
		local t = TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 })
		t.Completed:Once(function()
			d:Destroy()
		end)
		t:Play()
	end)
end

local function burst(at: Vector3, color: Color3, n: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 1
	pe.Enabled = false
	pe.Parent = p
	pe:Emit(n)
	Debris:AddItem(p, 1.2)
end

local function beam(at: Vector3, color: Color3)
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Cylinder
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
	b.Material = Enum.Material.Neon
	b.Color = color
	b.Transparency = 0.35
	b.Size = Vector3.new(120, 3, 3)
	b.CFrame = CFrame.new(at + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
	b.Parent = folder
	TweenService:Create(b, TweenInfo.new(2), { Transparency = 1, Size = Vector3.new(120, 6, 6) }):Play()
	Debris:AddItem(b, 2)
end

local function shelfPoint(owner: number): Vector3?
	for _, plot in (workspace:WaitForChild("Plots")):GetChildren() do
		if plot:GetAttribute("OwnerUserId") == owner then
			local i = plot:GetAttribute("PlotIndex") :: number
			local p = M.shelfPoint(i)
			return Vector3.new(p[1], p[2] + 0.2, p[3] + 4)
		end
	end
	return nil
end

local function groundY(p: Vector3): number
	return if p.Z < 0 then M.TerraceTop + 0.2 else M.Valley.y
end

------------------------------------------------------------------ goo
local function onFling(owner: number, start: Vector3, segs: { any }, gooTier: number, perfect: boolean, t0: number, bounces: number)
	if #goos >= MAX_GOO then
		return
	end
	local starts, total, from = {}, 0, start
	for _, s in segs do
		s.from = from
		s.to = s.endPos
		from = s.endPos
		table.insert(starts, total)
		total += s.time
	end
	local tier = E.Goo[gooTier] or E.Goo[1]
	local color = gooColor(gooTier)
	table.insert(goos, { blob = makeBlob(color), segs = segs, starts = starts, t0 = t0, total = total, owner = owner, seg = 1, color = color, rainbow = tier.rainbow == true, perfect = perfect, bounces = bounces })
	if owner == player.UserId then
		if perfect then
			Candy.toast("PERFECT!", Palette.lemon)
			Sound.play("perfect")
		end
	end
end

local function stepGoo(t: number)
	for i = #goos, 1, -1 do
		local g = goos[i]
		local el = t - g.t0
		-- advance segments, firing bounce effects as each pad is reached
		while g.seg <= #g.segs and el >= g.starts[g.seg] + g.segs[g.seg].time do
			local s = g.segs[g.seg]
			if s.pad and s.pad > 0 then
				JellyPads.squash(s.pad)
				local k = g.seg
				pop(s.to + Vector3.new(0, 3, 0), "BOING!", Color3.fromHex(M.PadColors[(s.pad - 1) % #M.PadColors + 1]), 1)
				Sound.play("boing", 1 + 0.1 * (k - 1))
				if g.owner == player.UserId and k == 3 then
					local cam = workspace.CurrentCamera
					if cam then
						local fov = cam.FieldOfView
						cam.FieldOfView = fov + 4
						TweenService:Create(cam, TweenInfo.new(0.1), { FieldOfView = fov }):Play()
					end
				end
			end
			g.seg += 1
		end
		if g.seg > #g.segs then
			local last = g.segs[#g.segs]
			splat(last.to, g.color)
			Sound.play("splat", 1, 4, 0.2)
			if g.owner == player.UserId and g.bounces >= 2 then
				Candy.toast("BOING ×" .. g.bounces .. "!", Palette.sky)
			end
			g.blob:Destroy()
			table.remove(goos, i)
		else
			local s = g.segs[g.seg]
			local a = math.clamp((el - g.starts[g.seg]) / s.time, 0, 1)
			local pos = T.at(s, a)
			local ahead = T.at(s, math.min(1, a + 0.05))
			local look = if (ahead - pos).Magnitude > 1e-3 then CFrame.lookAt(pos, ahead) else CFrame.new(pos)
			g.blob:PivotTo(look)
			if g.rainbow then
				local c = Color3.fromHSV((t * 0.6) % 1, 0.7, 1)
				for _, d in g.blob:GetDescendants() do
					if d:IsA("BasePart") then
						d.Color = c
					end
				end
			end
		end
	end
end

------------------------------------------------------------------ squishies
local function onSpawned(owner: number, _uid: string, s: string, g: boolean, landPos: Vector3, landAt: number, arriveAt: number, _zone: number)
	local to = shelfPoint(owner)
	if not to or #hops >= MAX_HOP then
		return
	end
	table.insert(hops, { model = nil, from = landPos, to = to, landAt = landAt, arriveAt = arriveAt - G.ArrivalPad, owner = owner, s = s, g = g, popped = false, hops = 0, lastHop = 0, size = 1 })
end

local function popOut(h: Hop)
	h.popped = true
	local m = SquishyModel.build(h.s, 1, h.g)
	m.Parent = folder
	m:PivotTo(CFrame.new(h.from) * CFrame.Angles(0, math.atan2(h.to.X - h.from.X, h.to.Z - h.from.Z) + math.pi, 0))
	h.model = m
	local sp = S.ById[h.s]
	local rarityColor = Color3.fromHex(Z.RarityColors[sp.rarity])
	local ri = table.find(Z.Rarities, sp.rarity) or 1
	-- scale 0 -> 1.3 -> 1.0 over 0.35 s
	m:ScaleTo(0.05)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.35 and m.Parent do
			local a = (os.clock() - t0) / 0.35
			local k = if a < 0.6 then 0.05 + (1.3 - 0.05) * (a / 0.6) else 1.3 - 0.3 * ((a - 0.6) / 0.4)
			m:ScaleTo(math.max(0.05, k))
			RunService.RenderStepped:Wait()
		end
		if m.Parent then
			m:ScaleTo(1)
		end
	end)
	burst(h.from + Vector3.new(0, 1.5, 0), if ri >= 3 then rarityColor else Color3.new(1, 1, 1), if ri >= 3 then 40 else 14)
	Sound.play("pop_out", 1, 6, 0.2)
	if ri >= 5 then
		beam(h.from, rarityColor)
	end
	if h.owner == player.UserId then
		if ri >= 5 then
			Sound.play("legendary_fanfare")
		elseif ri >= 3 then
			Sound.play("rare_reveal")
		end
		if ri >= 3 then
			Flight.revealCard(h.s, h.g)
		end
	end
end

local function stepHops(t: number)
	for i = #hops, 1, -1 do
		local h = hops[i]
		if t >= h.arriveAt then
			if h.model then
				h.model:Destroy()
			end
			table.remove(hops, i)
		elseif t >= h.landAt then
			if not h.popped then
				popOut(h)
			end
			local m = h.model
			local start = h.landAt + 0.35
			if m and t > start then
				local dur = math.max(0.1, h.arriveAt - start)
				local a = math.clamp((t - start) / dur, 0, 1)
				local flat = h.from:Lerp(h.to, a)
				local dist = Vector3.new(h.to.X - h.from.X, 0, h.to.Z - h.from.Z).Magnitude
				local n = math.max(1, math.ceil(dist / 18))
				local u = (a * n) % 1
				local hopIndex = math.floor(a * n)
				local y = groundY(flat) + 4 * u * (1 - u) * 6
				local yaw = math.atan2(h.to.X - h.from.X, h.to.Z - h.from.Z) + math.pi
				m:PivotTo(CFrame.new(flat.X, y, flat.Z) * CFrame.Angles(0, yaw, 0))
				if hopIndex ~= h.hops then
					h.hops = hopIndex
					h.lastHop = os.clock()
					if (flat - (workspace.CurrentCamera :: Camera).CFrame.Position).Magnitude < 120 then
						Sound.play("hop", 1, 4, 0.2)
					end
				end
				-- squash for 0.08 s after each landing (Y 0.7)
				local since = os.clock() - h.lastHop
				local k = if since < 0.08 and h.hops > 0 then 0.85 else 1
				if math.abs(m:GetScale() - k) > 0.01 then
					m:ScaleTo(k)
				end
			end
		end
	end
end

-- top-centre card for Rare+ catches (2 s, non-blocking); set up in start()
Flight.revealCard = function(_s: string, _g: boolean) end

function Flight.start()
	folder = Instance.new("Folder")
	folder.Name = "Flights"
	folder.Parent = workspace
	local assets = ReplicatedStorage:WaitForChild("Assets")
	blobTemplate = assets:FindFirstChild("goo_blob") :: Model?

	local cardGui = Candy.screen("RevealCard", 12)
	Flight.revealCard = function(s: string, g: boolean)
		local sp = S.ById[s]
		local color = Color3.fromHex(Z.RarityColors[sp.rarity])
		local card = Candy.pill(cardGui, UDim2.fromOffset(440, 120), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240) })
		local band = Candy.pill(card, UDim2.fromOffset(440, 40), color, { Position = UDim2.fromOffset(0, 0) })
		local r = Candy.label(band, string.upper(sp.rarity) .. (if g then " ✨ GLITTER" else ""), { Font = Enum.Font.FredokaOne, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4) })
		Candy.textStroke(r, 2)
		Candy.label(card, sp.name, { Font = Enum.Font.FredokaOne, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 42) })
		Candy.label(card, Format.abbrev(sp.income * (if g then Z.GlitterMult else 1)) .. " coins/s", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromHex("#4DB52E"), Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 88) })
		local sc = Instance.new("UIScale")
		sc.Scale = 0.5
		sc.Parent = card
		TweenService:Create(sc, Candy.POP, { Scale = 1 }):Play()
		task.delay(2, function()
			card:Destroy()
		end)
	end

	Net.listen("FlingVisual", onFling)
	Net.listen("SquishySpawned", onSpawned)
	Net.listen("Arrived", function(_uid: string, s: string, _g: boolean, isNew: boolean)
		local sp = S.ById[s]
		if isNew and sp then
			Candy.toast("New squishy: " .. sp.name .. "!", Color3.fromHex(Z.RarityColors[sp.rarity]))
		end
	end)
	RunService.RenderStepped:Connect(function()
		local t = now()
		stepGoo(t)
		stepHops(t)
	end)
end

return Flight
