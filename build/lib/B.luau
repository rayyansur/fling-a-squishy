--!nocheck
-- Builder helpers. Runs inside Lune; all Roblox datatypes come from R.
local roblox = require("@lune/roblox")

local I, E = roblox.Instance, roblox.Enum
local V3, CF, C3 = roblox.Vector3, roblox.CFrame, roblox.Color3
local UDim2 = roblox.UDim2

local B = {}
B.R = roblox
B.V3, B.CF, B.C3, B.E, B.I = V3, CF, C3, E, I
B.partCount = 0

local function hex(h: string)
	h = h:gsub("#", "")
	return C3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
B.hex = hex

local function col(c)
	if typeof(c) == "string" then
		return hex(c)
	end
	return c
end
B.col = col

function B.folder(parent, name)
	local f = I.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function B.model(parent, name)
	local m = I.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Generic part. o = {name, size=V3, cf=CF, color, mat, class, shape, t (transparency), refl, cc (CanCollide), shadow, ct (CanTouch), cq (CanQuery)}
function B.part(parent, o)
	local p = I.new(o.class or "Part")
	p.Name = o.name or "Part"
	p.Anchored = if o.anchored == nil then true else o.anchored
	p.Size = o.size
	p.CFrame = o.cf
	p.Color = col(o.color or "#cccccc")
	p.Material = E.Material[o.mat or "SmoothPlastic"]
	p.TopSurface = E.SurfaceType.Smooth
	p.BottomSurface = E.SurfaceType.Smooth
	if o.shape and (o.class == nil or o.class == "Part") then
		p.Shape = E.PartType[o.shape]
	end
	if o.t then
		p.Transparency = o.t
	end
	if o.refl then
		p.Reflectance = o.refl
	end
	if o.cc == false then
		p.CanCollide = false
	end
	if o.shadow == false then
		p.CastShadow = false
	end
	if o.ct == false then
		p.CanTouch = false
	end
	if o.cq == false then
		p.CanQuery = false
	end
	if o.massless then
		p.Massless = true
	end
	p.Parent = parent
	B.partCount += 1
	return p
end

-- Axis-aligned box from min/max corners.
function B.boxMM(parent, name, x0, y0, z0, x1, y1, z1, color, mat, extra)
	local o = extra or {}
	o.name = name
	o.size = V3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	o.cf = CF.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

-- Box by center + size, optional yaw (degrees).
function B.box(parent, name, cx, cy, cz, sx, sy, sz, color, mat, extra)
	local o = extra or {}
	o.name = name
	o.size = V3.new(sx, sy, sz)
	o.cf = CF.new(cx, cy, cz) * (o.rot or CF.new())
	o.rot = nil
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

-- Vertical cylinder (Roblox cylinders run along X, so rotate onto Y).
function B.vcyl(parent, name, cx, cy, cz, diameter, height, color, mat, extra)
	local o = extra or {}
	o.name = name
	o.size = V3.new(height, diameter, diameter)
	o.cf = CF.new(cx, cy, cz) * CF.Angles(0, 0, math.rad(90))
	o.shape = "Cylinder"
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

-- Cylinder along X.
function B.xcyl(parent, name, cx, cy, cz, diameter, length, color, mat, extra)
	local o = extra or {}
	o.name = name
	o.size = V3.new(length, diameter, diameter)
	o.cf = CF.new(cx, cy, cz) * (o.rot or CF.new())
	o.rot = nil
	o.shape = "Cylinder"
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

-- Cylinder along Z.
function B.zcyl(parent, name, cx, cy, cz, diameter, length, color, mat, extra)
	local o = extra or {}
	o.name = name
	o.size = V3.new(length, diameter, diameter)
	o.cf = CF.new(cx, cy, cz) * CF.Angles(0, math.rad(90), 0)
	o.shape = "Cylinder"
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

function B.ball(parent, name, cx, cy, cz, d, color, mat, extra)
	local o = extra or {}
	o.name = name
	o.size = V3.new(d, d, d)
	o.cf = CF.new(cx, cy, cz)
	o.shape = "Ball"
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

-- A beam between two points (box), thickness w x h.
function B.beam(parent, name, a, b, w, h, color, mat, extra)
	local o = extra or {}
	o.name = name
	local len = (b - a).Magnitude
	o.size = V3.new(w, h, len)
	o.cf = CF.lookAt((a + b) / 2, b)
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

function B.light(parent, kind, o)
	local l = I.new(kind)
	l.Color = col(o.color or "#ffd8a0")
	l.Brightness = o.brightness or 1
	l.Range = o.range or 12
	l.Shadows = o.shadows or false
	if kind ~= "PointLight" then
		l.Face = E.NormalId[o.face or "Bottom"]
		if kind == "SpotLight" or kind == "SurfaceLight" then
			l.Angle = o.angle or 90
		end
	end
	l.Parent = parent
	return l
end

-- SurfaceGui with labels. labels = {{text, font, color, pos={x,y}, size={w,h}, stroke, strokeColor, rot, bg, bgT, align}}
function B.surface(part, face, o)
	local sg = I.new("SurfaceGui")
	sg.Name = o.name or "Sign"
	sg.Face = E.NormalId[face]
	sg.SizingMode = E.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = o.ppu or 50
	sg.LightInfluence = if o.lit == false then 0 else (o.lightInfluence or 1)
	sg.Brightness = o.brightness or 1
	sg.AlwaysOnTop = false
	sg.ResetOnSpawn = false
	sg.ClipsDescendants = true
	sg.Parent = part
	for i, lb in ipairs(o.labels or {}) do
		local kind = if lb.text then "TextLabel" else "Frame"
		local t = I.new(kind)
		t.Name = lb.name or (kind .. i)
		t.BackgroundTransparency = lb.bgT or 1
		t.BackgroundColor3 = col(lb.bg or "#000000")
		t.BorderSizePixel = 0
		local pos = lb.pos or { 0, 0 }
		local size = lb.size or { 1, 1 }
		t.Position = UDim2.fromScale(pos[1], pos[2])
		t.Size = UDim2.fromScale(size[1], size[2])
		t.Rotation = lb.rot or 0
		t.ZIndex = lb.z or i
		if kind == "TextLabel" then
			t.Text = lb.text
			t.FontFace = roblox.Font.fromEnum(E.Font[lb.font or "FredokaOne"])
			t.TextColor3 = col(lb.color or "#ffffff")
			t.TextScaled = true
			t.TextWrapped = lb.wrap or false
			t.TextXAlignment = E.TextXAlignment[lb.align or "Center"]
			t.TextYAlignment = E.TextYAlignment[lb.valign or "Center"]
			if lb.stroke then
				t.TextStrokeTransparency = lb.stroke
				t.TextStrokeColor3 = col(lb.strokeColor or "#000000")
			else
				t.TextStrokeTransparency = 1
			end
			t.LineHeight = lb.lineHeight or 1
		end
		if lb.corner then
			local c = I.new("UICorner")
			c.CornerRadius = roblox.UDim.new(lb.corner, 0)
			c.Parent = t
		end
		t.Parent = sg
	end
	return sg
end

function B.particles(parent, o)
	local pe = I.new("ParticleEmitter")
	pe.Name = o.name or "Steam"
	pe.Texture = o.texture or "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = roblox.ColorSequence.new(col(o.color or "#ffffff"))
	pe.LightEmission = o.emission or 0.2
	pe.LightInfluence = o.influence or 0.6
	local s0, s1 = o.size0 or 0.6, o.size1 or 2.4
	pe.Size = roblox.NumberSequence.new({
		roblox.NumberSequenceKeypoint.new(0, s0),
		roblox.NumberSequenceKeypoint.new(1, s1),
	})
	pe.Transparency = roblox.NumberSequence.new({
		roblox.NumberSequenceKeypoint.new(0, 1),
		roblox.NumberSequenceKeypoint.new(0.2, o.alpha or 0.65),
		roblox.NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = roblox.NumberRange.new(o.life0 or 1.2, o.life1 or 2.2)
	pe.Rate = o.rate or 6
	pe.Speed = roblox.NumberRange.new(o.speed0 or 1.5, o.speed1 or 3)
	pe.SpreadAngle = roblox.Vector2.new(o.spread or 12, o.spread or 12)
	pe.RotSpeed = roblox.NumberRange.new(-30, 30)
	pe.Rotation = roblox.NumberRange.new(0, 360)
	pe.Acceleration = V3.new(0, o.accel or 0.6, 0)
	pe.EmissionDirection = E.NormalId.Top
	pe.Enabled = if o.enabled == nil then true else o.enabled
	pe.Parent = parent
	return pe
end

function B.prompt(parent, o)
	local pp = I.new("ProximityPrompt")
	pp.Name = o.name or "Prompt"
	pp.ActionText = o.action or "Use"
	pp.ObjectText = o.object or ""
	pp.HoldDuration = o.hold or 0
	pp.MaxActivationDistance = o.dist or 8
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = E.KeyCode[o.key or "E"]
	pp.Style = E.ProximityPromptStyle.Default
	pp.UIOffset = roblox.Vector2.new(0, o.uiOffset or 0)
	pp.Enabled = if o.enabled == nil then true else o.enabled
	pp.Parent = parent
	return pp
end

-- Simple wedge whose slope rises toward -Z by default.
function B.wedge(parent, name, cf, size, color, mat, extra)
	local o = extra or {}
	o.class = "WedgePart"
	o.name = name
	o.cf = cf
	o.size = size
	o.color = color
	o.mat = mat
	return B.part(parent, o)
end

function B.weldAll(model, root)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = I.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
		end
	end
end

-- Deterministic RNG so builds are reproducible.
function B.rng(seed)
	local s = seed
	return function(a, b)
		s = (s * 1103515245 + 12345) % 2147483648
		local r = s / 2147483648
		if a == nil then
			return r
		end
		if b == nil then
			return math.floor(r * a) + 1
		end
		return a + r * (b - a)
	end
end

function B.pick(rand, list)
	return list[math.floor(rand() * #list) + 1]
end

-- Prebuilt instances from a .rbxm/.rbxmx (a Studio export, or a map ported from an older place),
-- parented under `parent`. Tags, attributes and SurfaceGuis come along. Returns the root instances.
function B.import(parent, path)
	local fs = require("@lune/fs")
	local roots = roblox.deserializeModel(fs.readFile(path))
	for _, inst in roots do
		if inst:IsA("BasePart") then
			B.partCount += 1
		end
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				B.partCount += 1
			end
		end
		inst.Parent = parent
	end
	return roots
end

return B
