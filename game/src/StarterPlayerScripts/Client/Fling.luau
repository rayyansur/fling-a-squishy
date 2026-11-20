--!strict
-- Hold FLING to charge (0 -> 1 -> 0 every 0.9 s), aim with the camera (±30°), release to fling
-- (DESIGN 3.2-3.4, 9.4, 9.5). Draws the dotted arc preview, pulls the pouch and the arm back.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local T = require(ReplicatedStorage.Shared.Util.Trajectory)
local Net = require(ReplicatedStorage.Kit.Net)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local G, M, E = Config.Game, Config.Map, Config.Economy
local player = Players.LocalPlayer
local rules = T.rulesFrom(M)

local Fling = {}
Fling.charging = false
Fling.lastSend = -math.huge

local t0 = 0
local charge = 0
local atSling = false
local state = "loading"
local preview: { BasePart } = {}
local previewFolder: Folder
local stretch: Sound? = nil
local armKick = 0 -- seconds left of the release swing
local DOTS = 18

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

local function pouchRest(): CFrame?
	local fp = flingPoint()
	return fp and CFrame.new(fp)
end

local function triangle(t: number): number
	local phase = (t % G.ChargeCycle) / G.ChargeCycle
	return if phase < 0.5 then phase * 2 else 2 - phase * 2
end

local function yaw(): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 0
	end
	local look = cam.CFrame.LookVector
	local deg = math.deg(math.atan2(look.X, look.Z))
	return math.clamp(deg, -G.AimClampDeg, G.AimClampDeg)
end

local function currentLength(c: number): number
	local sp = (player:GetAttribute("sp") :: number?) or 1
	local goo = (player:GetAttribute("goo") :: number?) or 1
	local re = (player:GetAttribute("reSquishes") :: number?) or 0
	local rain = workspace:GetAttribute("GooRain") == true
	local curve = T.chargeCurve(c, G.SweetSpot, E.ChargeFloor)
	return T.power(sp, E.Goo[goo].mult, re, rain, E) * curve
end

local function showPreview(on: boolean)
	for _, d in preview do
		d.Transparency = if on then 0.15 else 1
	end
end

local function updatePreview()
	local fp = flingPoint()
	if not fp then
		return
	end
	local len = currentLength(charge)
	local path = T.compute(fp, T.direction(yaw()), len, {}, rules)
	local seg = path.segments[1]
	for i, d in preview do
		local a = i / DOTS
		d.Position = T.at(seg, a)
		d.Color = if charge >= G.SweetSpot then Color3.fromHex("#FFD23F") else Color3.fromHex("#FFFFFF")
	end
end

local function canFling(): boolean
	return state == "ready"
end

local function begin()
	if Fling.charging or not canFling() then
		return
	end
	Fling.charging = true
	t0 = os.clock()
	showPreview(true)
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.15), { FieldOfView = 62 }):Play()
	end
	stretch = Sound.loop("sling_stretch")
	if stretch then
		stretch:Play()
	end
end

local function snapPouch()
	local p = plot()
	local pouch = p and p:FindFirstChild("Pouch") :: BasePart?
	local rest = pouchRest()
	if not pouch or not rest then
		return
	end
	local over = TweenService:Create(pouch, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rest * CFrame.new(0, 0, 1) })
	over.Completed:Once(function()
		TweenService:Create(pouch, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = rest }):Play()
	end)
	over:Play()
end

local function release()
	if not Fling.charging then
		return
	end
	Fling.charging = false
	showPreview(false)
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.15), { FieldOfView = 70 }):Play()
	end
	if stretch then
		stretch:Stop()
	end
	local c = charge
	charge = 0
	Hud.setCharge(0)
	snapPouch()
	armKick = 0.25
	if os.clock() - Fling.lastSend < G.FlingCooldown or not canFling() then
		return
	end
	Fling.lastSend = os.clock()
	Sound.play("sling_release", 0.95 + math.random() * 0.1)
	Net.send("FlingRequest", c, yaw())
end

local function cancel()
	if Fling.charging then
		Fling.charging = false
		charge = 0
		showPreview(false)
		Hud.setCharge(0)
		if stretch then
			stretch:Stop()
		end
		local cam = workspace.CurrentCamera
		if cam then
			TweenService:Create(cam, TweenInfo.new(0.15), { FieldOfView = 70 }):Play()
		end
		snapPouch()
	end
end

-- right shoulder joint (Motor6D or AnimationConstraint, HANDBOOK 7)
local function shoulder(): Instance?
	local char = player.Character
	local arm = char and char:FindFirstChild("RightUpperArm")
	if not arm then
		return nil
	end
	for _, d in arm:GetChildren() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and d.Name == "RightShoulder" then
			return d
		end
	end
	return arm:FindFirstChild("RightShoulder")
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
	while not Hud.ready do
		task.wait()
	end
	previewFolder = Instance.new("Folder")
	previewFolder.Name = "FlingPreview"
	previewFolder.Parent = workspace
	for _ = 1, DOTS do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.new(0.7, 0.7, 0.7)
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
	Hud.setFlingState("loading")

	-- the HUD button
	local face = Hud.flingFace :: GuiButton
	face.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			begin()
		end
	end)
	face.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	-- mouse left in the world, gamepad R2
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.ButtonR2 or (input.UserInputType == Enum.UserInputType.MouseButton1 and not processed) then
			if atSling then
				begin()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
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
					begin()
				elseif inputState == Enum.UserInputState.End then
					release()
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
		local p = plot()
		local pouch = p and p:FindFirstChild("Pouch") :: BasePart?
		local rest = pouchRest()
		if Fling.charging then
			charge = triangle(now - t0)
			Hud.setCharge(charge)
			updatePreview()
			if stretch then
				stretch.PlaybackSpeed = 0.9 + 0.5 * charge
			end
			if pouch and rest then
				pouch.CFrame = rest * CFrame.new(0, 0, -4 * charge)
			end
		end
		if armKick > 0 then
			armKick = math.max(0, armKick - dt)
		end
	end)
	-- arm pose: back up to 60° while charging, a -30° swing on release
	RunService.Stepped:Connect(function()
		local j = shoulder()
		if not j then
			return
		end
		local angle = 0
		if Fling.charging then
			angle = 60 * charge
		elseif armKick > 0 then
			angle = -30 * math.sin(armKick / 0.25 * math.pi)
		end
		if angle ~= 0 then
			(j :: any).Transform = CFrame.Angles(math.rad(angle), 0, 0)
		end
	end)
end

return Fling
