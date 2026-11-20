--!strict
-- Re-Squish (DESIGN 4.9): needs coins >= 2.5B x 4^(n-1) and a Legendary+ on the shelf. Resets
-- progress, keeps the Dex/stats/streak/settings, grants income x(1 + 0.5n) and distance
-- x(1 + 0.1n), and sends everyone home with a goo wipe. Squishies still hopping are dropped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local R = require(ReplicatedStorage.Shared.Util.ReSquish)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local State = require(script.Parent.State)
local Plots = require(script.Parent.Plots)
local Economy = require(script.Parent.Economy)
local Shelf = require(script.Parent.Shelf)
local Analytics = require(script.Parent.Analytics)
local Progress = require(script.Parent.Progress)

local E, S, Z = Config.Economy, Config.Squishies, Config.Zones
local ReSquish = {}

function ReSquish.publish(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local coinsOk, legOk = R.check(data, E, S, Z.Rarities)
	player:SetAttribute("ReSquishCost", R.cost(data, E))
	player:SetAttribute("ReSquishLegendary", legOk)
	player:SetAttribute("ReSquishReady", coinsOk and legOk)
end

function ReSquish.run(player: Player): boolean
	local data = Data.get(player)
	if not data then
		return false
	end
	local coinsOk, legOk = R.check(data, E, S, Z.Rarities)
	if not (coinsOk and legOk) then
		return false
	end
	local n = 0
	Data.update(player, function(d)
		R.apply(d)
		n = d.reSquishes
	end)
	local st = State.get(player)
	st.epoch += 1
	st.readyAt = {}
	st.fullQueue = {}
	Net.fire(player, "ShelfFull", nil, nil, 0) -- close an open Shelf Full prompt
	Shelf.send(player)
	Economy.refresh(player)
	Plots.publishShelf(player)
	Analytics.custom(player, "ReSquish", n)
	Progress.emit(player, "resquish", n)
	Net.fire(player, "ReSquished", n)
	-- the wipe covers the screen, then everyone lands back at their slingshot
	task.delay(0.8, function()
		if player.Parent then
			Plots.teleportHome(player)
		end
	end)
	ReSquish.publish(player)
	return true
end

function ReSquish.start()
	Net.declare({ "ReSquished" })
	Net.on("ReSquish", { rate = 1, burst = 2 }, function(player)
		ReSquish.run(player)
	end)
	Data.onLoaded(ReSquish.publish)
	-- cheap enough to refresh with the income tick: attributes only change when the answer does
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in game:GetService("Players"):GetPlayers() do
				ReSquish.publish(p)
			end
		end
	end)
end

return ReSquish
