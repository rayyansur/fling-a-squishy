--!strict
-- BuyUpgrade (DESIGN 4.2, 4.6, 4.7, 6.3): goo, gloves, shelf slots, shelf level. Only the next
-- tier can be bought, at the server's price.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local Economy = require(script.Parent.Economy)
local Plots = require(script.Parent.Plots)
local Tutorial = require(script.Parent.Tutorial)
local Shelf = require(script.Parent.Shelf)

local E = Config.Economy
local Upgrades = {}

-- (cost, field, sink name) for buying `tier` of `kind`, or nil if it isn't the next tier
function Upgrades.price(data: any, kind: string, tier: number): (number?, string?, string?)
	if kind == "goo" and tier == data.goo + 1 and E.Goo[tier] then
		return E.Goo[tier].cost, "goo", "Goo"
	elseif kind == "gloves" and tier == data.gloves + 1 and E.Gloves[tier] then
		return E.Gloves[tier].cost, "gloves", "Gloves"
	elseif kind == "slots" and tier == data.slotUpgrades + 1 and data.slotUpgrades < E.MaxSlotUpgrades then
		return E.slotCost(data.slotUpgrades), "slotUpgrades", "Slots"
	elseif kind == "shelf" and tier == data.shelfLevel + 1 and E.ShelfLevels[tier] then
		return E.ShelfLevels[tier].cost, "shelfLevel", "ShelfLevel"
	end
	return nil
end

function Upgrades.buy(player: Player, kind: string, tier: number): boolean
	local data = Data.get(player)
	if not data then
		return false
	end
	local cost, field, sink = Upgrades.price(data, kind, tier)
	if not cost or not field or not sink then
		return false
	end
	if not Economy.spend(player, cost, sink) then
		Net.fire(player, "BuyResult", kind, tier, false)
		return false
	end
	Data.update(player, function(d)
		d[field] = tier
	end)
	Tutorial.onBuy(player, kind)
	Net.fire(player, "BuyResult", kind, tier, true)
	if kind == "slots" or kind == "shelf" then
		Shelf.send(player)
	end
	Economy.refresh(player)
	Plots.publishShelf(player)
	return true
end

function Upgrades.start()
	Net.declare({ "BuyResult" })
	Net.on("BuyUpgrade", { args = { "string", "int" }, rate = 6, maxString = 10 }, function(player, kind, tier)
		Upgrades.buy(player, kind, tier)
	end)
end

return Upgrades
