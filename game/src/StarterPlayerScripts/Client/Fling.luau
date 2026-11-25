--!strict
-- The throw (DESIGN 3.2-3.4, 19). Hold THROW (mouse left in the world, the HUD button, Space or
-- R2) to charge: the meter climbs 0 -> 1 -> 0 every ChargeCycle and the gold band is PERFECT.
-- Aim: the mouse cursor on the valley, or A/D / arrows / thumbstick while charging, or drag the
-- THROW finger sideways on a phone (±AimClampDeg). The preview shows the whole path, pad
-- bounces included, and a landing ring in the zone's colour. You stand still while charging.
-- A press shorter than MinHold throws nothing, and a new squishy takes FlingCooldown to load.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local T = require(ReplicatedStorage.Shared.Util.Trajectory)
local Palette = require(ReplicatedStorage.Shared.Theme).Palette
local Net = require(ReplicatedStorage.Kit.Net)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local G, M, E, Z = Config.Game, Config.Map, Config.Economy, Config.Zones
local GOLD, WHITE = Color3.fromHex("#FFD23F"), Color3.fromHex("#FFFFFF")
local player = Players.LocalPlayer
local rules = T.rulesFrom(M)

local Fling = {}
Fling.charging = false
Fling.lastSend = -math.huge

local t0 = 0
local charge = 0
local aimYaw = 0
local atSling = false
local state = "loading"
local stretch: Sound? = nil

-- who is holding: "mouse" | "touch" | "space" | "pad"; a touch hold is tied to its InputObject
local holding: string? = nil
local holdTouch: InputObject? = nil
local holdStartX = 0
local holdStartYaw = 0
local savedWalk: number? = nil
local lastMouse = Vector2.new(-1, -1)
local loadedShown = true

-- the pull: you stand STAND studs behind the pouch, facing the aim; the pouch comes back up to
-- PULL studs towards your face and both arms reach for it
local STAND, PULL = 5.2, 3.0
local releaseT = 0 -- seconds left of the release follow-through
local pouchPos: Vector3? = nil -- where the pouch is while pulled (world)
local loadBall: Part

local DOTS = 32
local preview: { BasePart } = {}
local previewFolder: Folder
local landRing: Part
local landLabel: TextLabel
local controls: any = nil

local function plot(): Model?
	local i = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return plots and i and plots:FindFirstChild("Plot" .. tostring(i)) :: Model?
end

local function flingPoint(): Vector3?
	local p = plot()
	local anchor = p and p:FindFirstChild("FlingAnchor")
	local att = anchor and anchor:FindFirstChild("FlingPoint") :: Attachment?
	return att and att.WorldPosition
end

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- +1 when "right on screen" is +X, -1 when the camera looks along +Z (right is -X)
local function screenSign(): number
	local cam = workspace.CurrentCamera
	return if cam and cam.CFrame.RightVector.X < 0 then -1 else 1
end

local function reloadLeft(): number
	return math.max(0, Fling.lastSend + G.FlingCooldown - os.clock())
end

-- predicted first-segment length for a charge, including PERFECT and the streak it would make
local function currentLength(c: number): number
	local sp = (player:GetAttribute("sp") :: number?) or 1
	local goo = (player:GetAttribute("goo") :: number?) or 1
	local re = (player:GetAttribute("reSquishes") :: number?) or 0
	local rain = workspace:GetAttribute("GooRain") == true
	local curve, perfect = T.chargeCurve(c, G.SweetSpot, E.ChargeFloor, E.PerfectMult)
	local sling = E.Slingshots[(player:GetAttribute("sling") :: number?) or 1] or E.Slingshots[1]
	local len = T.power(sp, E.Goo[goo].mult * sling.mult, re, rain, E) * curve
	if perfect then
		local streak = math.min(G.PerfectStreakMax, ((player:GetAttribute("PerfectStreak") :: number?) or 0) + 1)
		len *= T.streakMult(streak, G.PerfectStreakDist)
	end
	return len
end

local function showPreview(on: boolean)
	for _, d in preview do
		d.Transparency = if on then 0.15 else 1
	end
	landRing.Transparency = if on then 0.25 else 1
	local bb = landRing:FindFirstChildOfClass("BillboardGui")
	if bb then
		bb.Enabled = on
	end
end

local function updatePreview()
	local fp = flingPoint()
	if not fp then
		return
	end
	local path = T.compute(fp, T.direction(aimYaw), currentLength(charge), M.JellyPads, rules)
	local total = 0
	for _, seg in path.segments do
		total += seg.time
	end
	local col = if charge >= G.SweetSpot then GOLD else WHITE
	-- dots spread evenly in flight time across every segment, bounces included
	local si, acc = 1, 0
	for i, d in preview do
		local tt = total * i / DOTS
		while si < #path.segments and tt > acc + path.segments[si].time do
			acc += path.segments[si].time
			si += 1
		end
		local seg = path.segments[si]
		d.Position = T.at(seg, math.clamp((tt - acc) / seg.time, 0, 1))
		d.Color = col
	end
	local zone = T.zoneOf(path.distance, Z.List)
	local info = Z.List[zone]
	landRing.CFrame = CFrame.new(path.final + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	-- white reads on every zone's ground (the meadow is green like its zone colour); gold = bounce
	landRing.Color = if path.bounces > 0 then GOLD else WHITE
	landLabel.TextColor3 = if path.bounces > 0 then GOLD else Color3.fromHex(info.color)
	landLabel.Text = if path.bounces > 0 then ("%s  ·  BOING ×%d"):format(info.name, path.bounces) else info.name
end

local function canFling(): boolean
	return state == "ready"
end

local function freeze(on: boolean)
	local hum = humanoid()
	if not hum then
		return
	end
	if on and savedWalk == nil then
		savedWalk = hum.WalkSpeed
		hum.WalkSpeed = 0
		hum.AutoRotate = false
	elseif not on and savedWalk ~= nil then
		hum.WalkSpeed = savedWalk
		hum.AutoRotate = true
		savedWalk = nil
	end
end

-- stand behind the pouch facing the aim, stepping back as the pull grows
local function placeBody(fp: Vector3, dir: Vector3)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local at = Vector3.new(fp.X, root.Position.Y, fp.Z) - dir * (STAND + 0.8 * charge)
	root.CFrame = CFrame.lookAt(at, at + dir)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function setFov(fov: number)
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.15), { FieldOfView = fov }):Play()
	end
end

-- start the meter (called on press, or as soon as the reload ends while still held)
local function startCharge()
	if Fling.charging or not canFling() then
		return
	end
	Fling.charging = true
	t0 = os.clock()
	charge = 0
	Net.send("ChargeBegin")
	showPreview(true)
	freeze(true)
	setFov(62)
	stretch = Sound.loop("sling_stretch")
	if stretch then
		stretch:Play()
	end
end

local function snapPouch()
	local p = plot()
	local pouch = p and p:FindFirstChild("Pouch") :: BasePart?
	local fp = flingPoint()
	if not pouch or not fp then
		return
	end
	local rest = CFrame.new(fp)
	local over = TweenService:Create(pouch, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rest + T.direction(aimYaw) * 1.6 })
	over.Completed:Once(function()
		TweenService:Create(pouch, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = rest }):Play()
	end)
	over:Play()
end

-- stop charging without throwing
local function stopCharge()
	if not Fling.charging then
		return
	end
	Fling.charging = false
	charge = 0
	pouchPos = nil
	showPreview(false)
	freeze(false)
	setFov(70)
	Hud.setCharge(0)
	if stretch then
		stretch:Stop()
	end
	snapPouch()
end

local function press(kind: string, input: InputObject?)
	if holding or not canFling() then
		return
	end
	holding = kind
	holdTouch = if kind == "touch" then input else nil
	holdStartX = if input then input.Position.X else 0
	holdStartYaw = aimYaw
	if reloadLeft() <= 0 then
		startCharge()
	end -- otherwise the RenderStepped loop starts it when the squishy has loaded
end

local function release(kind: string, input: InputObject?)
	if holding ~= kind or (kind == "touch" and input ~= holdTouch) then
		return
	end
	holding, holdTouch = nil, nil
	if not Fling.charging then
		return -- let go during the reload: nothing to throw yet
	end
	local held = os.clock() - t0
	local c = charge
	stopCharge()
	if held < G.MinHold then
		Candy.toast("Hold to charge!", Palette.pink)
		return
	end
	if not canFling() then
		return
	end
	releaseT = 0.35
	Fling.lastSend = os.clock()
	loadedShown = false
	Sound.play("sling_release", 0.95 + math.random() * 0.1)
	Net.send("FlingRequest", c, aimYaw)
end

local function cancel()
	holding, holdTouch = nil, nil
	stopCharge()
end

-- mouse cursor on the valley floor -> yaw (ignored while the cursor is over the terrace)
local function mouseAim()
	if not UserInputService.MouseEnabled then
		return
	end
	local pos = UserInputService:GetMouseLocation()
	if pos == lastMouse then
		return
	end
	lastMouse = pos
	local cam = workspace.CurrentCamera
	local fp = flingPoint()
	if not cam or not fp then
		return
	end
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local d = ray.Direction
	if d.Y >= -1e-3 then
		-- above the horizon: aim along the cursor's horizontal direction
		if d.Z > 0.05 then
			aimYaw = math.clamp(math.deg(math.atan2(d.X, d.Z)), -G.AimClampDeg, G.AimClampDeg)
		end
		return
	end
	local hit = ray.Origin + d * ((M.Valley.y - ray.Origin.Y) / d.Y)
	local dx, dz = hit.X - fp.X, hit.Z - fp.Z
	if dz > 4 then
		aimYaw = math.clamp(math.deg(math.atan2(dx, dz)), -G.AimClampDeg, G.AimClampDeg)
	end
end

local function updateState()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fp = flingPoint()
	atSling = false
	if root and fp then
		local d = Vector3.new(root.Position.X - fp.X, 0, root.Position.Z - fp.Z).Magnitude
		atSling = d <= G.FlingReach
	end
	local newState
	if not player:GetAttribute("Ready") then
		newState = "loading"
	elseif not atSling then
		newState = "away"
	elseif ((player:GetAttribute("Hopping") :: number?) or 0) >= G.MaxHopping then
		newState = "busy"
	else
		newState = "ready"
	end
	if newState ~= state then
		state = newState
		Hud.setFlingState(state)
		if state ~= "ready" then
			cancel()
		end
	end
end

local function makePreview()
	previewFolder = Instance.new("Folder")
	previewFolder.Name = "FlingPreview"
	previewFolder.Parent = workspace
	for i = 1, DOTS do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		local s = if i == DOTS then 0.9 else 0.6
		d.Size = Vector3.new(s, s, s)
		d.Material = Enum.Material.Neon
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Transparency = 1
		d.Parent = previewFolder
		table.insert(preview, d)
	end
	loadBall = Instance.new("Part")
	loadBall.Name = "LoadedGoo"
	loadBall.Shape = Enum.PartType.Ball
	loadBall.Size = Vector3.new(1.4, 1.4, 1.4)
	loadBall.Material = Enum.Material.SmoothPlastic
	loadBall.Anchored = true
	loadBall.CanCollide = false
	loadBall.CanQuery = false
	loadBall.CanTouch = false
	loadBall.Transparency = 1
	loadBall.Parent = previewFolder
	landRing = Instance.new("Part")
	landRing.Name = "LandRing"
	landRing.Shape = Enum.PartType.Cylinder
	landRing.Size = Vector3.new(0.3, 10, 10)
	landRing.Material = Enum.Material.Neon
	landRing.Anchored = true
	landRing.CanCollide = false
	landRing.CanQuery = false
	landRing.CanTouch = false
	landRing.CastShadow = false
	landRing.Transparency = 1
	landRing.Parent = previewFolder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(280, 44)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	bb.Parent = landRing
	landLabel = Candy.label(bb, "", { Size = UDim2.fromScale(1, 1), TextColor3 = WHITE })
	Candy.textStroke(landLabel, 2)
end

function Fling.start()
	player:GetAttributeChangedSignal("HomeSeq"):Connect(function()
		task.wait()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cam = workspace.CurrentCamera
		if root and cam then
			local p = root.Position
			cam.CFrame = CFrame.lookAt(p + Vector3.new(0, 7, -14), p + Vector3.new(0, 2, 12))
		end
	end)
	task.spawn(function()
		local ok, pm = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		end)
		if ok and pm then
			controls = pm:GetControls()
		end
	end)
	while not Hud.ready do
		task.wait()
	end
	makePreview()
	Hud.setFlingState("loading")

	-- the HUD button (mouse or a finger on it)
	local face = Hud.flingFace :: GuiButton
	face.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			press("mouse", input)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			press("touch", input)
		end
	end)
	-- mouse left in the world, gamepad R2
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			if atSling then
				press("pad", input)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			if atSling then
				mouseAim()
				press("mouse", input)
			end
		end
	end)
	-- every release goes through here, so a finger sliding off the button still throws and the
	-- movement thumb lifting never does
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			release("pad", input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			release("mouse", input)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			release("touch", input)
		end
	end)
	-- the THROW finger steers when dragged sideways
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if holding == "touch" and input == holdTouch then
			local dx = input.Position.X - holdStartX
			aimYaw = math.clamp(holdStartYaw + dx * G.TouchDegPerPixel * screenSign(), -G.AimClampDeg, G.AimClampDeg)
		end
	end)
	-- Space at the slingshot charges instead of jumping
	local bound = false
	local function bindSpace(on: boolean)
		if on == bound then
			return
		end
		bound = on
		if on then
			ContextActionService:BindActionAtPriority("FlingSpace", function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					press("space", nil)
				elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
					release("space", nil)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)
		else
			ContextActionService:UnbindAction("FlingSpace")
		end
	end

	local last = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now - last > 0.1 then
			last = now
			updateState()
			bindSpace(atSling and state ~= "loading")
		end
		-- reload: the ring refills, then a pop when the next squishy is loaded
		local left = reloadLeft()
		if left > 0 then
			Hud.setReload(1 - left / G.FlingCooldown)
		elseif not loadedShown then
			loadedShown = true
			Hud.setCharge(0)
			Hud.popFling()
		end
		if holding and not Fling.charging and left <= 0 then
			startCharge()
		end
		if atSling then
			mouseAim()
		end
		local pp = plot()
		local pouch = pp and pp:FindFirstChild("Pouch") :: BasePart?
		if Fling.charging then
			-- keyboard / thumbstick steering
			local mv: Vector3 = if controls then controls:GetMoveVector() else Vector3.zero
			if math.abs(mv.X) > 0.1 then
				aimYaw = math.clamp(aimYaw + mv.X * G.SteerDegPerSec * dt * screenSign(), -G.AimClampDeg, G.AimClampDeg)
			end
			charge = T.chargeAt(now - t0, G.ChargeCycle)
			Hud.setCharge(charge)
			updatePreview()
			if stretch then
				stretch.PlaybackSpeed = 0.9 + 0.5 * charge
			end
			local fp = flingPoint()
			if fp then
				local dir = T.direction(aimYaw)
				-- ease-out pull: quick at first, heavy near full stretch
				local k = 1 - (1 - charge) ^ 2
				pouchPos = fp - dir * PULL * k - Vector3.new(0, 0.9 * k, 0)
				placeBody(fp, dir)
				if pouch then
					pouch.CFrame = CFrame.lookAt(pouchPos :: Vector3, (pouchPos :: Vector3) + dir)
				end
			end
		end
		if releaseT > 0 then
			releaseT = math.max(0, releaseT - dt)
		end
		-- the loaded goo sits in the pouch until it's thrown, then reloads
		local loaded = atSling and state == "ready" and left <= 0
		if loaded and pouch then
			local goo = E.Goo[(player:GetAttribute("goo") :: number?) or 1] or E.Goo[1]
			loadBall.Color = Color3.fromHex(goo.color)
			loadBall.CFrame = pouch.CFrame * CFrame.new(0, 0.45, 0)
			loadBall.Transparency = 0
		else
			loadBall.Transparency = 1
		end
	end)
	-- arms: while charging both arms point at the pouch (aim the hanging arm along shoulder ->
	-- pouch in the torso's space); on release they follow through forward and settle
	RunService.Stepped:Connect(function()
		local char = player.Character
		local torso = char and char:FindFirstChild("UpperTorso") :: BasePart?
		if not torso then
			return
		end
		local fp = flingPoint()
		local target: Vector3? = nil
		local weight = 0
		if Fling.charging and pouchPos then
			target, weight = pouchPos, 1
		elseif releaseT > 0 and fp then
			target, weight = fp + T.direction(aimYaw) * 6, releaseT / 0.35
		end
		if not target then
			return
		end
		for _, side in { "Right", "Left" } do
			local arm = char:FindFirstChild(side .. "UpperArm")
			local joint = arm and arm:FindFirstChild(side .. "Shoulder")
			if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
				local c0 = if joint:IsA("Motor6D") then joint.C0 else CFrame.new()
				local shoulderWorld = torso.CFrame * c0
				local want = shoulderWorld:VectorToObjectSpace(((target :: Vector3) - shoulderWorld.Position).Unit)
				local down = Vector3.new(0, -1, 0)
				local axis = down:Cross(want)
				local rot = if axis.Magnitude > 1e-4 then CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(down:Dot(want), -1, 1)) * weight) else CFrame.new()
				local j: any = joint
				j.Transform = rot
			end
			local fore = char:FindFirstChild(side .. "LowerArm")
			local elbow = fore and fore:FindFirstChild(side .. "Elbow")
			if elbow and elbow:IsA("Motor6D") then
				elbow.Transform = CFrame.Angles(math.rad(25 * charge * weight), 0, 0)
			end
		end
	end)
	-- respawn mid-charge: drop the hold so the old WalkSpeed isn't put on the new character
	player.CharacterAdded:Connect(function()
		savedWalk = nil
		cancel()
	end)
end

return Fling
