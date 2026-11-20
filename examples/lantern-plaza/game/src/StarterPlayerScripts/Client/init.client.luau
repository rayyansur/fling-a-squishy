--!strict
-- Client entry: a small hint label so playtests show the UI path works.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Hint"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -24)
label.Size = UDim2.fromOffset(360, 44)
label.BackgroundColor3 = Color3.fromRGB(255, 244, 224)
label.TextColor3 = Color3.fromRGB(43, 33, 24)
label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
label.TextScaled = true
label.Text = Config.Hint
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = label

gui.Parent = player:WaitForChild("PlayerGui")
