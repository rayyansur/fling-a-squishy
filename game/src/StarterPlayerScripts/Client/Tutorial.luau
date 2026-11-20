--!strict
-- Onboarding hints (DESIGN 5): the hint chip, a pulsing hot-pink arrow beam to the target, and
-- a pulse on the button for each step. The server owns the step ("TutorialStep" attribute).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local Candy = require(script.Parent.Candy)

local player = Players.LocalPlayer
local M = Config.Map

local Tutorial = {}

local HINTS = {
	[1] = { text = "Hold FLING, let go in the gold!", button = "Fling", target = "sling" },
	[2] = { text = "BOING! Jelly Pads bounce you farther!", button = "Fling", target = "sling" },
	[3] = { text = "Squishies make coins every second! Press SQUEEZE for a burst!", button = "Squeeze", target = "shelf" },
	[4] = { text = "Get 3 of the same to MERGE!", button = "Fling", target = "sling" },
	[5] = { text = "Buy Lime Slime goo to fling farther!", button = "Upgrades", target = "goo" },
}

local stopPulse: (() -> ())? = nil
local beam: Beam? = nil
local a0: Attachment, a1: Attachment

local function targetPos(kind: string): Vector3?
	local i = player:GetAttribute("Plot") :: number?
	if kind == "goo" then
		local g = M.Hub.GooLab
		return Vector3.new(g[1], M.TerraceTop + 6, g[2])
	end
	if not i then
		return nil
	end
	if kind == "shelf" then
		local p = M.shelfPoint(i)
		return Vector3.new(p[1], p[2] + 8, p[3])
	end
	local p = M.flingPoint(i)
	return Vector3.new(p[1], p[2] + 2, p[3])
end

local function show(step: number)
	if stopPulse then
		stopPulse()
		stopPulse = nil
	end
	local h = HINTS[step]
	Hud.hint(if h then h.text else nil)
	if not h then
		if beam then
			beam.Enabled = false
		end
		return
	end
	local btn = Hud.buttons[h.button]
	if btn then
		stopPulse = Candy.pulse(btn)
	end
end

function Tutorial.start()
	while not Hud.ready do
		task.wait()
	end
	-- arrow: a beam from the character to the target, animated texture scroll
	local holder = Instance.new("Part")
	holder.Name = "TutorialArrow"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
	holder.Size = Vector3.one
	holder.Parent = workspace
	a0 = Instance.new("Attachment")
	a0.Parent = holder
	a1 = Instance.new("Attachment")
	a1.Parent = holder
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = ColorSequence.new(Color3.fromHex("#FF4FA3"))
	b.Width0, b.Width1 = 1.6, 0.4
	b.FaceCamera = true
	b.LightEmission = 0.6
	b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 3
	b.TextureSpeed = 2
	b.Transparency = NumberSequence.new(0.1)
	b.Enabled = false
	b.Parent = holder
	beam = b

	local function refresh()
		local step = (player:GetAttribute("TutorialStep") :: number?) or 0
		show(step)
	end
	player:GetAttributeChangedSignal("TutorialStep"):Connect(refresh)
	refresh()

	game:GetService("RunService").Heartbeat:Connect(function()
		local step = (player:GetAttribute("TutorialStep") :: number?) or 0
		local h = HINTS[step]
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local target = h and targetPos(h.target)
		if not (h and root and target) or not beam then
			if beam then
				beam.Enabled = false
			end
			return
		end
		-- hide the arrow once you're standing at the target
		local near = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude < 9
		beam.Enabled = not near
		a0.WorldPosition = root.Position + Vector3.new(0, 1, 0)
		a1.WorldPosition = target
		beam.Width0 = 1.4 + 0.4 * math.sin(os.clock() * 6)
	end)
end

return Tutorial
