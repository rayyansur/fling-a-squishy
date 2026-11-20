--!strict
-- Onboarding (DESIGN 5). The step lives in the "TutorialStep" attribute (0 = done); the client
-- shows the hint chip, arrow and pulses. Steps only move forward.
--   1 hold FLING · 2 BOING! · 3 squeeze · 4 merge · 5 buy Lime Slime · done after the first goo
--   purchase or 10 flings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ServerScriptService.Kit.Data)
local Analytics = require(script.Parent.Analytics)

local Tutorial = {}

local function step(player: Player): number
	return (player:GetAttribute("TutorialStep") :: number?) or 0
end

local function finish(player: Player)
	if step(player) == 0 then
		return
	end
	player:SetAttribute("TutorialStep", 0)
	Data.update(player, function(d)
		d.tutorialDone = true
	end)
	Analytics.funnel(player, 8)
end

local function advance(player: Player, n: number)
	local s = step(player)
	if s ~= 0 and n > s then
		player:SetAttribute("TutorialStep", n)
	end
end

function Tutorial.active(player: Player): boolean
	return step(player) ~= 0
end

-- called by Fling after a fling is accepted (flings = lifetime count after this one)
function Tutorial.onFling(player: Player, flings: number, bounced: boolean)
	if flings == 1 then
		Analytics.funnel(player, 2)
	end
	if bounced then
		Analytics.funnel(player, 3)
	end
	if not Tutorial.active(player) then
		return
	end
	local data = Data.get(player)
	if not data then
		return
	end
	Data.update(player, function(d)
		d.tutorialFlings += 1
	end)
	if data.tutorialFlings >= Config.Game.TutorialFlings then
		finish(player)
	elseif data.tutorialFlings == 1 then
		advance(player, 2)
	elseif data.tutorialFlings >= 3 then
		advance(player, 4)
	end
end

function Tutorial.onArrive(player: Player)
	Analytics.funnel(player, 4)
	advance(player, 3)
end

function Tutorial.onSqueeze(player: Player)
	Analytics.funnel(player, 5)
end

function Tutorial.onMerge(player: Player)
	Analytics.funnel(player, 6)
end

function Tutorial.onCoins(player: Player, coins: number)
	if Tutorial.active(player) and coins >= Config.Game.TutorialCoinsHint and step(player) >= 3 then
		advance(player, 5)
	end
end

function Tutorial.onBuy(player: Player, kind: string)
	Analytics.funnel(player, 7)
	if kind == "goo" then
		finish(player)
	end
end

-- should this fling be the rigged first fling / the rigged third fling?
function Tutorial.rigFirst(player: Player): boolean
	local data = Data.get(player)
	return data ~= nil and Tutorial.active(player) and data.tutorialFlings == 0
end

function Tutorial.rigThird(player: Player): boolean
	local data = Data.get(player)
	return data ~= nil and Tutorial.active(player) and data.tutorialFlings == 2
end

function Tutorial.start()
	Data.onLoaded(function(player, data)
		Analytics.funnel(player, 1)
		player:SetAttribute("TutorialStep", if data.tutorialDone then 0 else 1)
	end)
	Data.changed:Connect(function(player: Player, data: any)
		Tutorial.onCoins(player, data.coins)
	end)
end

return Tutorial
