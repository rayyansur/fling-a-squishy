--!strict
-- Coins: the income tick (DESIGN 3.10), leaderstats (4.14), adding and spending with analytics.
-- Income is recomputed whenever the shelf or a multiplier changes, and paid once per second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Income = require(ReplicatedStorage.Shared.Util.Income)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Products = require(ReplicatedStorage.Kit.Products)
local Data = require(ServerScriptService.Kit.Data)
local State = require(script.Parent.State)
local Plots = require(script.Parent.Plots)
local Analytics = require(script.Parent.Analytics)

local S, Z, E, Mo = Config.Squishies, Config.Zones, Config.Economy, Config.Monetization

local Economy = {}
Economy.partyUntil = 0 -- Squish Party end (server time); set by the shop

function Economy.partyActive(): boolean
	return workspace:GetServerTimeNow() < Economy.partyUntil
end

function Economy.hasCoinsPass(player: Player): boolean
	return player:GetAttribute(Products.passAttribute("coins_2x")) == true
end

-- multipliers for this player; withParty = false gives "current income" for coin packs
function Economy.mults(player: Player, data: any, withParty: boolean?): Income.Mults
	local party = (withParty ~= false) and Economy.partyActive()
	return Income.mults(data, E, Economy.hasCoinsPass(player), party, Mo.CoinsPassMult, Mo.PartyMult)
end

function Economy.incomeOf(player: Player, data: any, entry: any): number
	return Income.of(entry, S, Z, Economy.mults(player, data))
end

function Economy.incomePerSec(player: Player, data: any, withParty: boolean?): number
	return Income.total(data.shelf, S, Z, Economy.mults(player, data, withParty))
end

local function leaderstats(player: Player): Instance
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		return existing
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local sq = Instance.new("IntValue")
	sq.Name = "Squishies"
	sq.Parent = ls
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = "0"
	coins.Parent = ls
	ls.Parent = player
	return ls
end

local function setStats(player: Player, count: number?, coins: number)
	local ls = leaderstats(player)
	local sq = ls:FindFirstChild("Squishies") :: IntValue?
	local c = ls:FindFirstChild("Coins") :: StringValue?
	if sq and count then
		sq.Value = count
	end
	if c then
		c.Value = Format.abbrev(coins)
	end
end

function Economy.refresh(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local st = State.get(player)
	st.incomePerSec = Economy.incomePerSec(player, data)
	player:SetAttribute("IncomePerSec", st.incomePerSec)
	player:SetAttribute("ShelfCount", #data.shelf)
	player:SetAttribute("Slots", E.slotCount(data.slotUpgrades))
	setStats(player, #data.shelf, data.coins)
	Plots.refreshSign(player)
end

-- add coins (source name for analytics); returns the new balance
function Economy.add(player: Player, amount: number, source: string): number
	if amount ~= amount or amount <= 0 then
		return 0
	end
	local balance = 0
	Data.update(player, function(d)
		d.coins += amount
		d.stats.totalEarned += amount
		balance = d.coins
	end)
	setStats(player, nil, balance)
	if source ~= "Income" then
		Analytics.source(player, amount, balance, source)
	end
	return balance
end

-- spend if affordable; returns true when paid
function Economy.spend(player: Player, amount: number, sink: string): boolean
	local data = Data.get(player)
	if not data or amount ~= amount or amount < 0 or data.coins < amount then
		return false
	end
	local balance = 0
	Data.update(player, function(d)
		d.coins -= amount
		balance = d.coins
	end)
	Analytics.sink(player, amount, balance, sink)
	setStats(player, nil, balance)
	return true
end

function Economy.start()
	Data.onLoaded(function(player)
		Economy.refresh(player)
		Data.update(player, function(d)
			d.lastOnline = os.time()
		end)
	end)
	-- income tick: every shelved squishy pays directly into coins
	-- runs forever on its own thread so start() returns
	task.spawn(function()
		local saveTick = 0
		while true do
			task.wait(Config.Game.IncomeTick)
			saveTick += 1
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					local st = State.get(player)
					-- recompute each tick so a party starting/ending applies at once
					local per = Economy.incomePerSec(player, data)
					if per ~= st.incomePerSec then
						st.incomePerSec = per
						player:SetAttribute("IncomePerSec", per)
						Plots.refreshSign(player)
					end
					if per > 0 then
						Economy.add(player, per * Config.Game.IncomeTick, "Income")
						st.incomeAcc += per
					end
					if saveTick % 10 == 0 then
						Data.update(player, function(d)
							d.lastOnline = os.time()
							d.lastIncomePerSec = Economy.incomePerSec(player, d, false)
							d.stats.playSeconds += 10
						end)
						if st.incomeAcc > 0 then
							Analytics.source(player, st.incomeAcc, data.coins, "Income")
							st.incomeAcc = 0
						end
					end
				end
			end
		end
	end)
end

-- no writes on leave: Kit.Data is already saving the player by then, and the 10 s tick above
-- keeps lastOnline / lastIncomePerSec current (offline income tolerates 10 s of slack)

return Economy
