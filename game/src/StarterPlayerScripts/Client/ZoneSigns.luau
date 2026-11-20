--!strict
-- Floating zone signs (DESIGN 2.2): a big name per zone, visible to 1,100 studs, with an "i"
-- button that opens the odds. They live in PlayerGui so the button can be clicked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)

local Z = Config.Zones
local player = Players.LocalPlayer

local ZoneSigns = {}

function ZoneSigns.start()
	local valley = workspace:WaitForChild("Valley")
	local pg = player:WaitForChild("PlayerGui")
	local holder = Instance.new("Folder")
	holder.Name = "ZoneSigns"
	holder.Parent = pg
	for i, zone in Z.List do
		local anchor = valley:WaitForChild("ZoneSign" .. i, 10)
		if anchor and anchor:IsA("BasePart") then
			local bb = Instance.new("BillboardGui")
			bb.Name = "Zone" .. i
			bb.Adornee = anchor
			bb.Size = UDim2.fromScale(46, 9.5) -- studs: shrinks with distance like a real sign
			bb.MaxDistance = 1100
			bb.LightInfluence = 0
			bb.AlwaysOnTop = false
			bb.ResetOnSpawn = false
			bb.Active = true
			bb.Parent = holder
			local color = if i == 6 then Color3.fromHex("#FF4FA3") else Color3.fromHex(zone.color)
			local pill = Candy.pill(bb, UDim2.fromScale(0.98, 0.94), color, { Position = UDim2.fromScale(0.01, 0.03) })
			local l = Candy.label(pill, zone.sign, { Font = Enum.Font.FredokaOne, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0.78, 0.8), Position = UDim2.fromScale(0.03, 0.1) })
			Candy.textStroke(l, 3)
			Candy.button(pill, "i", "grape", UDim2.fromScale(0.14, 0.76), function()
				local open = Hud.panels.Odds
				if open then
					open(tostring(i))
				end
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.98, 0.5) })
		end
	end
end

return ZoneSigns
