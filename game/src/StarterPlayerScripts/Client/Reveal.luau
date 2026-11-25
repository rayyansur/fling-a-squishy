--!strict
-- Catch moments (DESIGN 21) for your own catches, queued so two rare catches never overlap:
--   level 1 (Rare/Epic, Big, Shiny): a top-centre card with the squishy spinning, 2.2 s;
--   level 2 (Legendary/Mythic, Giant, Galactic): a full-screen reveal: the screen dims, rays
--   spin behind a glow, the squishy pops in and turns, a big title drops, confetti falls.
--   3.4 s, click / tap to skip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Mod = require(ReplicatedStorage.Shared.Util.Modifier)
local Candy = require(script.Parent.Candy)
local Sound = require(script.Parent.Sound)
local SquishyModel = require(script.Parent.SquishyModel)

local S, Z = Config.Squishies, Config.Zones
local WHITE = Color3.new(1, 1, 1)
local CONFETTI = { "#FF4FA3", "#FFD23F", "#3EC5FF", "#7CF25A", "#9B5CFF", "#FF8A3D" }

local Reveal = {}

type Item = { s: string, g: boolean, mod: string? }
local queue: { Item } = {}
local running = false
local gui: ScreenGui = nil :: any

-- the colour of the moment: the modifier's for Giant/Galactic, else the rarity's
local function colorOf(it: Item): Color3
	local d = it.mod and Z.ModifierById[it.mod]
	if d and (it.mod == "giant" or it.mod == "galactic") then
		return Color3.fromHex(d.color)
	end
	return Color3.fromHex(Z.RarityColors[S.ById[it.s].rarity])
end

local function incomeText(it: Item): string
	return Format.abbrev(S.ById[it.s].income * Mod.incomeMult(Z, it.g, it.mod)) .. " coins/s"
end

-- a ViewportFrame with the squishy turning; returns the frame and a stop function
local function spinner(parent: Instance, it: Item, size: UDim2, pos: UDim2, anchor: Vector2): (ViewportFrame, () -> ())
	local vp = Candy.make("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = size,
		Position = pos,
		AnchorPoint = anchor,
		Ambient = Color3.fromRGB(210, 200, 230),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	local m = SquishyModel.build(it.s, 1, it.g, it.mod)
	m:PivotTo(CFrame.new())
	m.Parent = vp
	local cam = Instance.new("Camera")
	local boxCf, box = m:GetBoundingBox()
	local c = boxCf.Position
	local r = math.max(box.X, box.Y, box.Z)
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(c + Vector3.new(0, r * 0.4, -r * 2.5), c)
	cam.Parent = vp
	vp.CurrentCamera = cam
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local a = os.clock() - t0
		m:PivotTo(CFrame.Angles(0, a * 1.6, 0) * CFrame.new(0, 0.08 * r * math.abs(math.sin(a * 4)), 0))
	end)
	return vp, function()
		conn:Disconnect()
	end
end

local function card(it: Item)
	local sp = S.ById[it.s]
	local color = colorOf(it)
	local root = Candy.pill(gui, UDim2.fromOffset(520, 132), WHITE, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240) })
	local band = Candy.pill(root, UDim2.new(1, -132, 0, 40), color, { Position = UDim2.fromOffset(124, 8) })
	local d = it.mod and Z.ModifierById[it.mod]
	local tag = string.upper(sp.rarity) .. (if d then " · " .. string.upper(d.name) else "") .. (if it.g then " · SHINY" else "")
	local r = Candy.label(band, tag, { Font = Enum.Font.FredokaOne, TextColor3 = WHITE, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4) })
	Candy.textStroke(r, 2)
	Candy.label(root, Mod.title(Z, S, it.s, 1, it.g, it.mod), { Font = Enum.Font.FredokaOne, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.fromOffset(124, 50), TextXAlignment = Enum.TextXAlignment.Left })
	Candy.label(root, incomeText(it), { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromHex("#4DB52E"), Size = UDim2.new(1, -140, 0, 26), Position = UDim2.fromOffset(124, 94), TextXAlignment = Enum.TextXAlignment.Left })
	local _vp, stop = spinner(root, it, UDim2.fromOffset(116, 116), UDim2.fromOffset(6, 8), Vector2.zero)
	local sc = Candy.make("UIScale", { Scale = 0.5, Parent = root })
	TweenService:Create(sc, Candy.POP, { Scale = 1 }):Play()
	task.wait(2.2)
	local out = TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
	out:Play()
	out.Completed:Wait()
	stop()
	root:Destroy()
end

local function cinematic(it: Item)
	local sp = S.ById[it.s]
	local color = colorOf(it)
	local d = it.mod and Z.ModifierById[it.mod]
	local big = if it.mod == "galactic" or it.mod == "giant" then string.upper((d :: any).name) .. "!" else string.upper(sp.rarity) .. "!"
	local layer = Candy.make("Frame", { Name = "Cinematic", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local dim = Candy.make("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = layer })
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.4 }):Play()

	-- spinning rays behind a glow
	local center = Candy.make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(10, 10), Parent = layer })
	local rays = Candy.make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1400, 1400), Parent = center })
	for k = 0, 11 do
		Candy.make("Frame", {
			BackgroundColor3 = if k % 2 == 0 then color else WHITE,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(70, 1400),
			Rotation = k * 15,
			Parent = rays,
		})
	end
	local glow = Candy.make("Frame", { BackgroundColor3 = color, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 380), Parent = center })
	Candy.corner(glow, 190)
	local inner = Candy.make("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 260), Parent = center })
	Candy.corner(inner, 130)
	local _vp, stop = spinner(center, it, UDim2.fromOffset(420, 420), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local pop = Candy.make("UIScale", { Scale = 0.05, Parent = center })
	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- title drops in, name + income under it
	local title = Candy.label(layer, big, {
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.1),
		Size = UDim2.fromOffset(900, 110),
	})
	Candy.textStroke(title, 5)
	TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.16) }):Play()
	local name = Candy.label(layer, Mod.title(Z, S, it.s, 1, it.g, it.mod), { Font = Enum.Font.FredokaOne, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromOffset(900, 64) })
	Candy.textStroke(name, 4)
	local inc = Candy.label(layer, incomeText(it), { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromHex("#7CF25A"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromOffset(600, 40) })
	Candy.textStroke(inc, 3)
	local skip = Candy.label(layer, "click to continue", { Font = Enum.Font.GothamBold, TextColor3 = WHITE, TextTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(400, 28) })
	Candy.textStroke(skip, 2)

	-- confetti
	local rng = Random.new()
	local bits: { { f: Frame, vx: number, vy: number, spin: number } } = {}
	for _ = 1, 46 do
		local f = Candy.make("Frame", {
			BackgroundColor3 = Color3.fromHex(CONFETTI[rng:NextInteger(1, #CONFETTI)]),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.1, 0.9), rng:NextNumber(-0.3, -0.02)),
			Size = UDim2.fromOffset(rng:NextInteger(10, 18), rng:NextInteger(16, 26)),
			Rotation = rng:NextNumber(0, 360),
			Parent = layer,
		}) :: Frame
		table.insert(bits, { f = f, vx = rng:NextNumber(-0.05, 0.05), vy = rng:NextNumber(0.25, 0.45), spin = rng:NextNumber(-300, 300) })
	end

	local cam = workspace.CurrentCamera
	if cam then
		local fov = cam.FieldOfView
		cam.FieldOfView = fov + 6
		TweenService:Create(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
	end
	Sound.play("legendary_fanfare")

	local done = false
	dim.Activated:Connect(function()
		done = true
	end)
	local tapConn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonA then
			done = true
		end
	end)
	local t0 = os.clock()
	local step = RunService.RenderStepped:Connect(function(dt: number)
		rays.Rotation += dt * 25
		local a = os.clock() - t0
		glow.Size = UDim2.fromOffset(380 + 16 * math.sin(a * 5), 380 + 16 * math.sin(a * 5))
		for _, b in bits do
			b.f.Position += UDim2.fromScale(b.vx * dt, b.vy * dt)
			b.f.Rotation += b.spin * dt
		end
	end)
	while not done and os.clock() - t0 < 3.4 do
		task.wait()
	end
	tapConn:Disconnect()
	-- out: everything shrinks into the centre and the dim fades
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	for _, l in { title, name, inc, skip } do
		TweenService:Create(l, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		end
	end
	task.wait(0.28)
	step:Disconnect()
	stop()
	layer:Destroy()
end

local function pump()
	if running then
		return
	end
	running = true
	if not gui or not gui.Parent then
		local made = Candy.screen("Reveal", 30)
		made.IgnoreGuiInset = true -- the dim covers the top bar too
		gui = made
	end
	while #queue > 0 do
		local it = table.remove(queue, 1) :: Item
		local sp = S.ById[it.s]
		if sp then
			local level = Mod.moment(Z, sp.rarity, it.g, it.mod)
			if level >= 2 then
				cinematic(it)
			elseif level == 1 then
				card(it)
			end
		end
	end
	running = false
end

-- queue the moment for one of your catches (does nothing for plain commons)
function Reveal.show(s: string, g: boolean, mod: string?)
	table.insert(queue, { s = s, g = g, mod = Mod.clean(Z, mod) })
	task.spawn(pump)
end

function Reveal.start()
	if not gui or not gui.Parent then
		gui = Candy.screen("Reveal", 30)
	end
end

return Reveal
