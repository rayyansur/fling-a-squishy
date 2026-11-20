--!strict
-- Lamps: anything tagged "ToggleLamp" gets an on/off switch through its ProximityPrompt.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Lamps = {}

local function setOn(model: Instance, on: boolean)
	model:SetAttribute("On", on)
	for _, d in model:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = on
		elseif d:IsA("BasePart") and d.Name == "Glow" then
			d.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			d.Color = if on then Config.LampOnColor else Config.LampOffColor
		end
	end
end

function Lamps.setup(model: Instance)
	if model:GetAttribute("LampReady") then
		return
	end
	model:SetAttribute("LampReady", true)
	setOn(model, true)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Triggered:Connect(function(player: Player)
				local on = not model:GetAttribute("On")
				setOn(model, on)
				print(("%s turned the %s %s"):format(player.Name, model.Name, if on then "on" else "off"))
			end)
		end
	end
end

function Lamps.start()
	for _, m in CollectionService:GetTagged("ToggleLamp") do
		Lamps.setup(m)
	end
	CollectionService:GetInstanceAddedSignal("ToggleLamp"):Connect(Lamps.setup)
end

return Lamps
