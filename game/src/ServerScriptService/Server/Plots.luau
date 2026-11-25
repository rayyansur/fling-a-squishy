--!strict
-- Plot assignment (DESIGN 6.1): lowest free plot on join, "Loading…" until the save loads, then
-- teleport to the slingshot. On leave the plot is cleared. Also publishes each shelf as a
-- compact plot attribute so every client can draw every shelf.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local ConfigCheck = require(ReplicatedStorage.Shared.Util.ConfigCheck)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Data = require(ServerScriptService.Kit.Data)
local Net = require(ReplicatedStorage.Kit.Net)
local Products = require(ReplicatedStorage.Kit.Products)
local State = require(script.Parent.State)

local M = Config.Map
local Plots = {}
Plots.ready = false

local owners: { [number]: Player } = {}

local function folder(): Instance
	return workspace:WaitForChild("Plots")
end

function Plots.model(i: number): Model?
	return folder():FindFirstChild("Plot" .. i) :: Model?
end

function Plots.indexOf(player: Player): number?
	return State.get(player).plot
end

function Plots.flingPoint(i: number): Vector3
	local p = M.flingPoint(i)
	return Vector3.new(p[1], p[2], p[3])
end

function Plots.shelfPoint(i: number): Vector3
	local p = M.shelfPoint(i)
	return Vector3.new(p[1], p[2], p[3])
end

-- lowest free index, or nil when all are taken (pure, for tests)
function Plots.lowestFree(taken: { [number]: any }, count: number): number?
	for i = 1, count do
		if taken[i] == nil then
			return i
		end
	end
	return nil
end

local function sign(i: number): BillboardGui?
	local plot = Plots.model(i)
	local anchor = plot and plot:FindFirstChild("SignAnchor")
	return anchor and anchor:FindFirstChild("NameSign") :: BillboardGui?
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4F6E")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("#FF9A3D")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("#FFE14D")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("#7CF25A")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("#3EC5FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#B36BFF")),
})

function Plots.setSign(i: number, owner: string, income: string, title: string, rainbow: boolean?)
	local bb = sign(i)
	if not bb then
		return
	end
	local ownerLabel = bb:FindFirstChild("Owner") :: TextLabel
	ownerLabel.Text = owner
	-- Rainbow Trail pass: the owner's name in rainbow (white text so the gradient shows true)
	local grad = ownerLabel:FindFirstChild("Rainbow") :: UIGradient?
	if rainbow and not grad then
		local g = Instance.new("UIGradient")
		g.Name = "Rainbow"
		g.Color = RAINBOW
		g.Parent = ownerLabel
		ownerLabel:SetAttribute("BaseColor", ownerLabel.TextColor3)
		ownerLabel.TextColor3 = Color3.new(1, 1, 1)
	elseif not rainbow and grad then
		grad:Destroy()
		local base = ownerLabel:GetAttribute("BaseColor")
		if typeof(base) == "Color3" then
			ownerLabel.TextColor3 = base
		end
	end;
	(bb:FindFirstChild("Income") :: TextLabel).Text = income;
	(bb:FindFirstChild("Title") :: TextLabel).Text = title
end

function Plots.refreshSign(player: Player)
	local i = Plots.indexOf(player)
	local data = Data.get(player)
	if not i or not data then
		return
	end
	local title = if data.reSquishes > 0 then "Re-Squish " .. Format.roman(data.reSquishes) else ""
	local rainbow = player:GetAttribute(Products.passAttribute("rainbow_trail")) == true
	Plots.setSign(i, player.DisplayName, "+" .. Format.abbrev(State.get(player).incomePerSec) .. "/s", title, rainbow)
end

-- "speciesId:size:glitter;..." for other clients' shelf renderers
function Plots.encodeShelf(shelf: { any }): string
	local parts = table.create(#shelf)
	for _, e in shelf do
		table.insert(parts, ("%s:%d:%d"):format(e.s, e.z or 1, if e.g then 1 else 0))
	end
	return table.concat(parts, ";")
end

function Plots.publishShelf(player: Player)
	local i = Plots.indexOf(player)
	local data = Data.get(player)
	local plot = i and Plots.model(i)
	if plot and data then
		plot:SetAttribute("Shelf", Plots.encodeShelf(data.shelf))
		plot:SetAttribute("Slots", Config.Economy.slotCount(data.slotUpgrades))
		plot:SetAttribute("ShelfLevel", data.shelfLevel)
		plot:SetAttribute("Sling", data.sling or 1)
	end
end

function Plots.teleportHome(player: Player)
	local i = Plots.indexOf(player)
	local char = player.Character
	if not i or not char then
		return
	end
	local fp = Plots.flingPoint(i)
	local stand = Vector3.new(fp.X, M.TerraceTop + 3, fp.Z - 4)
	char:PivotTo(CFrame.lookAt(stand, stand + Vector3.new(0, 0, 1)))
	-- tells the client to put the camera behind the player, looking down the valley
	player:SetAttribute("HomeSeq", ((player:GetAttribute("HomeSeq") :: number?) or 0) + 1)
end

local function assign(player: Player)
	local i = Plots.lowestFree(owners, M.PlotCount)
	if not i then
		warn("[Plots] no free plot for " .. player.Name)
		return
	end
	owners[i] = player
	State.get(player).plot = i
	player:SetAttribute("Plot", i)
	local plot = Plots.model(i)
	if plot then
		plot:SetAttribute("OwnerUserId", player.UserId)
	end
	Plots.setSign(i, "Loading…", "", "")
end

local function release(player: Player)
	local i = State.get(player).plot
	if not i or owners[i] ~= player then
		return
	end
	owners[i] = nil
	local plot = Plots.model(i)
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("Shelf", "")
		plot:SetAttribute("Slots", nil)
		plot:SetAttribute("Sling", nil)
		plot:SetAttribute("ShelfLevel", nil)
	end
	Plots.setSign(i, "Free plot", "", "")
end

function Plots.start()
	local problems = ConfigCheck.run(Config)
	if #problems > 0 then
		error("[Config] " .. table.concat(problems, "; "))
	end
	Players.PlayerAdded:Connect(assign)
	for _, p in Players:GetPlayers() do
		if not State.get(p).plot then
			assign(p)
		end
	end
	Players.PlayerRemoving:Connect(release)
	Data.onLoaded(function(player)
		Plots.publishShelf(player)
		Plots.refreshSign(player)
		player:SetAttribute("Ready", true)
		Plots.teleportHome(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			Plots.teleportHome(player)
		end)
	end)
	Net.on("GoHome", { rate = 1, burst = 2 }, function(player)
		if player:GetAttribute("Ready") then
			Plots.teleportHome(player)
		end
	end)
	Plots.ready = true
end

return Plots
