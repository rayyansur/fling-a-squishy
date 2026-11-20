--!strict
-- Passes + products (DESIGN 10): what each one does. The kit handles prompts, receipts and saves.
--   coins_2x       Economy reads the Pass_coins_2x attribute (income and squeezes)
--   auto_fling     flings every 1.5 s at charge 0.80, straight, while standing at the slingshot
--   auto_squeeze   squeezes every ready squishy every 10 s
--   rainbow_trail  clients draw a trail on the owner's goo; the plot sign turns rainbow
--   coin_*         max(floor, N minutes of income without the party)
--   squish_party   server-wide x2 income, +5 min per purchase, at most 30 min queued
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Products = require(ReplicatedStorage.Kit.Products)
local Net = require(ReplicatedStorage.Kit.Net)
local Shop = require(ServerScriptService.Kit.Shop)
local Data = require(ServerScriptService.Kit.Data)
local Economy = require(script.Parent.Economy)
local Fling = require(script.Parent.Fling)
local Shelf = require(script.Parent.Shelf)
local Plots = require(script.Parent.Plots)
local Analytics = require(script.Parent.Analytics)

local Mo, G = Config.Monetization, Config.Game

local Store = {}

-- coins a pack grants for this save (pure; the Shop card shows the same number)
function Store.packAmount(key: string, baseIncome: number): number
	local p = Mo.CoinPacks[key]
	return math.floor(math.max(p.floor, baseIncome * p.minutes * 60))
end

-- new party end time after one purchase at `now` (pure)
function Store.extendParty(partyUntil: number, now: number): number
	local from = math.max(partyUntil, now)
	return math.min(from + Mo.PartyMinutes * 60, now + Mo.PartyMaxMinutes * 60)
end

function Store.startParty(byName: string)
	local now = workspace:GetServerTimeNow()
	Economy.partyUntil = Store.extendParty(Economy.partyUntil, now)
	workspace:SetAttribute("PartyUntil", Economy.partyUntil)
	Net.fireAll("Announce", ("%s started a Squish Party! 2x coins for everyone!"):format(byName), "Party")
	for _, p in Players:GetPlayers() do
		task.spawn(Economy.refresh, p)
	end
end

local function owns(player: Player, key: string): boolean
	return player:GetAttribute(Products.passAttribute(key)) == true
end

-- standing still at your own slingshot (pauses Auto-Fling while you walk)
local function readyToAutoFling(player: Player): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local i = Plots.indexOf(player)
	if not root or not i then
		return false
	end
	local v = root.AssemblyLinearVelocity
	if Vector3.new(v.X, 0, v.Z).Magnitude > 1.5 then
		return false
	end
	local fp = Plots.flingPoint(i)
	return Vector3.new(root.Position.X - fp.X, 0, root.Position.Z - fp.Z).Magnitude <= G.FlingReach
end

function Store.start()
	for k in Mo.CoinPacks do
		local key = k :: string
		Shop.onProduct(key, function(player, data)
			local amount = Store.packAmount(key, Economy.incomePerSec(player, data, false))
			data.coins += amount
			Analytics.source(player, amount, data.coins, "DevProduct")
		end)
	end
	Shop.onProduct("squish_party", function(player, _data)
		Store.startParty(player.DisplayName)
	end)
	Shop.onPass("coins_2x", function(player)
		Economy.refresh(player)
	end)
	Shop.onPass("rainbow_trail", function(player)
		Plots.refreshSign(player)
	end)
	Shop.onPass("auto_squeeze", function(player)
		if player:GetAttribute("AutoSqueeze") == nil then
			player:SetAttribute("AutoSqueeze", true)
		end
	end)
	Shop.onPass("auto_fling", function(player)
		if player:GetAttribute("AutoFling") == nil then
			player:SetAttribute("AutoFling", false)
		end
	end)

	-- HUD toggles (only for owners)
	Net.on("SetAuto", { args = { "string", "boolean" }, rate = 4, burst = 6, maxString = 16 }, function(player, which, on)
		if which == "fling" and owns(player, "auto_fling") then
			player:SetAttribute("AutoFling", on)
		elseif which == "squeeze" and owns(player, "auto_squeeze") then
			player:SetAttribute("AutoSqueeze", on)
		end
	end)

	-- the party ends by itself; clients read PartyUntil, income re-reads partyActive() every tick
	workspace:SetAttribute("PartyUntil", Economy.partyUntil)

	task.spawn(function()
		local sinceSqueeze = 0
		while true do
			task.wait(Mo.AutoFlingInterval)
			sinceSqueeze += Mo.AutoFlingInterval
			for _, p in Players:GetPlayers() do
				if owns(p, "auto_fling") and p:GetAttribute("AutoFling") == true and Data.get(p) and readyToAutoFling(p) then
					task.spawn(Fling.request, p, Mo.AutoFlingCharge, 0, true)
				end
			end
			if sinceSqueeze >= Mo.AutoSqueezeInterval then
				sinceSqueeze = 0
				for _, p in Players:GetPlayers() do
					if owns(p, "auto_squeeze") and p:GetAttribute("AutoSqueeze") ~= false and Data.get(p) then
						task.spawn(Shelf.squeeze, p)
					end
				end
			end
		end
	end)
end

return Store
