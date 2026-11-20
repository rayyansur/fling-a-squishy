--!strict
-- Goo Rain on the client (DESIGN 4.10): "Next Goo Rain mm:ss" chip, the 30 s warning, a rainbow
-- banner with a countdown while it runs, the sky tint, the Goo Rain music, and goo blobs falling
-- around the camera (pooled; off in Low Graphics). Timing comes from ReplicatedStorage attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local P, F = Theme.Palette, Theme.Fonts
local cfg = Config.Progress.GooRain
local player = Players.LocalPlayer
local GooRainFx = {}

local BLOBS = 30
local COLORS = { "#FF4FA3", "#7CF25A", "#3EC5FF", "#9B5CFF", "#FFD23F" }

local function mmss(s: number): string
	s = math.max(0, math.ceil(s))
	return ("%d:%02d"):format(s // 60, s % 60)
end

function GooRainFx.start()
	while not Hud.ready do
		task.wait()
	end
	local gui = Candy.screen("GooRain", 6)
	local chip = Candy.pill(gui, UDim2.fromOffset(330, 52), P.white, { Name = "GooRainChip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24) })
	local chipLabel = Candy.label(chip, "", { Font = F.header, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6) })
	local grad = Candy.make("UIGradient", {
		Enabled = false,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4FA3")),
			ColorSequenceKeypoint.new(0.25, Color3.fromHex("#FFD23F")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#7CF25A")),
			ColorSequenceKeypoint.new(0.75, Color3.fromHex("#3EC5FF")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#9B5CFF")),
		}),
		Parent = chip,
	})
	local labelStroke = Candy.textStroke(chipLabel, 2) :: any

	local cc: ColorCorrectionEffect? = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local baseTint = if cc then cc.TintColor else Color3.new(1, 1, 1)
	local rainTint = Color3.fromHex(cfg.Tint)

	-- falling goo pool
	local folder = Instance.new("Folder")
	folder.Name = "GooRainDecor"
	folder.Parent = workspace
	local blobs: { { part: Part, vel: number } } = {}
	for i = 1, BLOBS do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * (0.8 + (i % 4) * 0.35)
		b.Color = Color3.fromHex(COLORS[i % #COLORS + 1])
		b.Material = Enum.Material.SmoothPlastic
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
		b.Transparency = 1
		b.Parent = folder
		table.insert(blobs, { part = b, vel = 0 })
	end
	local rng = Random.new()
	local function respawn(entry: { part: Part, vel: number }, cam: Vector3, top: boolean)
		local y = if top then cam.Y + rng:NextNumber(35, 60) else cam.Y + rng:NextNumber(-10, 60)
		entry.part.Position = cam + Vector3.new(rng:NextNumber(-70, 70), y - cam.Y, rng:NextNumber(-70, 70))
		entry.vel = rng:NextNumber(22, 36)
	end

	local active = false
	local warned = -1
	local decorOn = false
	local function setActive(on: boolean)
		if on == active then
			return
		end
		active = on
		grad.Enabled = on
		chip.BackgroundColor3 = if on then P.white else P.white
		chipLabel.TextColor3 = if on then P.white else P.ink
		if labelStroke and labelStroke:IsA("UIStroke") then
			labelStroke.Enabled = on
		end
		chip.Size = UDim2.fromOffset(if on then 420 else 330, if on then 64 else 52)
		if cc then
			TweenService:Create(cc, TweenInfo.new(1.2), { TintColor = if on then rainTint else baseTint }):Play()
		end
		Sound.music(if on then "goo_rain" else "main_theme")
		if on then
			Hud.announce("GOO RAIN! Farther flings, double Rare+ luck!", P.pink)
		end
	end

	local spin = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local s = ReplicatedStorage:GetAttribute("GooRainStart") :: number?
		local f = ReplicatedStorage:GetAttribute("GooRainEnd") :: number?
		if not s or not f then
			chip.Visible = false
			return
		end
		chip.Visible = true
		local now = workspace:GetServerTimeNow()
		local on = now >= s and now < f
		setActive(on)
		if on then
			chipLabel.Text = "GOO RAIN!  " .. mmss(f - now)
			spin = (spin + dt * 180) % 360
			grad.Rotation = spin
		else
			chipLabel.Text = "Next Goo Rain " .. mmss(s - now)
			local left = s - now
			if left <= cfg.Warning and left > 0 and warned ~= s then
				warned = s
				Hud.announce("GOO RAIN in " .. mmss(left) .. "!", P.grape)
				Sound.play("goo_rain_jingle")
			end
		end
		-- decor
		local want = on and player:GetAttribute("SetLow") ~= true
		local cam = workspace.CurrentCamera
		if want and cam then
			local cp = cam.CFrame.Position
			for _, e in blobs do
				if not decorOn then
					respawn(e, cp, false)
					e.part.Transparency = 0.1
				end
				local p = e.part.Position - Vector3.new(0, e.vel * dt, 0)
				if p.Y < cp.Y - 25 or (Vector3.new(p.X - cp.X, 0, p.Z - cp.Z)).Magnitude > 110 then
					respawn(e, cp, true)
				else
					e.part.Position = p
				end
			end
			decorOn = true
		elseif decorOn then
			decorOn = false
			for _, e in blobs do
				e.part.Transparency = 1
			end
		end
	end)
end

return GooRainFx
