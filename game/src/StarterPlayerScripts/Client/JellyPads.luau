--!strict
-- Jelly Pad idle wobble (scale Y 1 <-> 0.85, 0.8 s) and the squash on a bounce (DESIGN 2.3).
-- Also squashes each plot's Squeeze Pad when SQUEEZE is pressed.
local RunService = game:GetService("RunService")

local JellyPads = {}

type Rig = { base: CFrame, parts: { { part: BasePart, size: Vector3, offset: CFrame } }, phase: number, squashAt: number, squashDepth: number }
local rigs: { [number]: Rig } = {}
local squeezeRigs: { [number]: Rig } = {}

local function rig(model: Model): Rig
	local base = model:GetPivot()
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, { part = d, size = d.Size, offset = base:ToObjectSpace(d.CFrame) })
		end
	end
	return { base = base, parts = parts, phase = math.random() * math.pi * 2, squashAt = -math.huge, squashDepth = 0.5 }
end

local function apply(r: Rig, k: number)
	for _, p in r.parts do
		local o = p.offset
		p.part.Size = Vector3.new(p.size.X, p.size.Y * k, p.size.Z)
		p.part.CFrame = r.base * CFrame.new(o.X, o.Y * k, o.Z) * (o - o.Position)
	end
end

-- squash curve: down to depth, elastic back over 0.5 s
local function squashK(r: Rig, now: number): number
	local t = now - r.squashAt
	if t < 0 or t > 0.5 then
		return 1
	end
	local a = t / 0.5
	return 1 - r.squashDepth * math.exp(-6 * a) * math.cos(a * math.pi * 3)
end

function JellyPads.squash(i: number)
	local r = rigs[i]
	if r then
		r.squashAt = os.clock()
	end
end

function JellyPads.squeeze(plotIndex: number)
	local r = squeezeRigs[plotIndex]
	if r then
		r.squashAt = os.clock()
	end
end

function JellyPads.position(i: number): Vector3?
	local r = rigs[i]
	return r and r.base.Position
end

function JellyPads.start()
	local folder = workspace:WaitForChild("JellyPads")
	for _, m in folder:GetChildren() do
		local i = m:GetAttribute("PadIndex")
		if m:IsA("Model") and type(i) == "number" then
			rigs[i] = rig(m)
		end
	end
	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		local pad = plot:FindFirstChild("SqueezePad")
		local i = plot:GetAttribute("PlotIndex")
		if pad and pad:IsA("Model") and type(i) == "number" then
			local r = rig(pad)
			r.squashDepth = 0.45
			squeezeRigs[i] = r
		end
	end
	-- idle wobble at 30 Hz within 300 studs; squashes (short, rare) run every frame
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		local now = os.clock()
		local idleFrame = acc >= 1 / 30
		if idleFrame then
			acc = 0
		end
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		for _, r in rigs do
			local squashing = now - r.squashAt < 0.5
			if (squashing or idleFrame) and (r.base.Position - camPos).Magnitude < 300 then
				local idle = 0.925 + 0.075 * math.cos(now / 0.8 * math.pi * 2 + r.phase)
				apply(r, idle * squashK(r, now))
			end
		end
		for _, r in squeezeRigs do
			if now - r.squashAt < 0.6 then
				apply(r, squashK(r, now))
			end
		end
	end)
end

return JellyPads
