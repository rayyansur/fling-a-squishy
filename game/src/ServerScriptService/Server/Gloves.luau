--!strict
-- Glove colour on the avatar (DESIGN 4.7): a candy mitt welded to each hand in the owned gloves'
-- colour; Bare Hands shows none. Sprinkle and Rainbow gloves sparkle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local E = Config.Economy
local Gloves = {}

local HANDS = { "RightHand", "LeftHand", "Right Arm", "Left Arm" }

function Gloves.apply(player: Player)
	local char = player.Character
	if not char then
		return
	end
	for _, c in char:GetChildren() do
		if c.Name == "CandyGlove" then
			c:Destroy()
		end
	end
	local tier = (player:GetAttribute("gloves") :: number?) or 1
	local g = E.Gloves[tier]
	if not g or not g.color then
		return
	end
	for _, handName in HANDS do
		local hand = char:FindFirstChild(handName)
		if hand and hand:IsA("BasePart") then
			local mitt = Instance.new("Part")
			mitt.Name = "CandyGlove"
			mitt.Shape = Enum.PartType.Ball
			local w = math.max(hand.Size.X, hand.Size.Z) * 1.25
			mitt.Size = Vector3.new(w, w, w)
			mitt.Color = Color3.fromHex(g.color)
			mitt.Material = Enum.Material.SmoothPlastic
			mitt.CanCollide, mitt.CanQuery, mitt.CanTouch, mitt.Massless = false, false, false, true
			-- R15 hands are short; R6 arms are long, so sit the mitt at the bottom of the arm
			local down = if handName:find("Arm") then -hand.Size.Y / 2 + w / 2 else 0
			mitt.CFrame = hand.CFrame * CFrame.new(0, down, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = hand, mitt
			weld.Parent = mitt
			if g.sprinkles or g.rainbow then
				local pe = Instance.new("ParticleEmitter")
				pe.Rate = 4
				pe.Lifetime = NumberRange.new(0.5, 0.8)
				pe.Speed = NumberRange.new(0.5, 1)
				pe.Size = NumberSequence.new(0.15)
				pe.LightEmission = 0.6
				pe.Color = if g.rainbow
					then ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4FA3")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FFD23F")), ColorSequenceKeypoint.new(1, Color3.fromHex("#3EC5FF")) })
					else ColorSequence.new(Color3.new(1, 1, 1))
				pe.Parent = mitt
			end
			mitt.Parent = char
		end
	end
end

function Gloves.start()
	local function hook(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			Gloves.apply(player)
		end)
		player:GetAttributeChangedSignal("gloves"):Connect(function()
			Gloves.apply(player)
		end)
		if player.Character then
			Gloves.apply(player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return Gloves
