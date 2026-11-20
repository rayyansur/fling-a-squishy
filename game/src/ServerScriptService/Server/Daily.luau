--!strict
-- 7-day calendar + 3 daily quests (DESIGN 4.12). UTC days; a missed day resets the calendar.
-- Quest progress comes from Progress events. The client gets one "DailyState" snapshot (on
-- join, on claim, at most once a second while quests move) and a DailyReady attribute for "!".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local D = require(ReplicatedStorage.Shared.Util.Daily)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local Economy = require(script.Parent.Economy)
local Shelf = require(script.Parent.Shelf)
local Progress = require(script.Parent.Progress)
local Dev = require(script.Parent.Dev)

local Pr, S, Z = Config.Progress, Config.Squishies, Config.Zones
local Daily = {}
local dirty: { [Player]: boolean } = {}
local dayOffset = 0 -- Studio Dev command shifts "today" to test streaks

local function today(): number
	return D.day(os.time()) + dayOffset
end

local function income(player: Player, data: any): number
	return Economy.incomePerSec(player, data, false)
end

-- make sure today's quests exist; true if they were regenerated
local function ensureQuests(player: Player): boolean
	local reset = false
	Data.update(player, function(d)
		reset = D.refreshQuests(d.quests, Pr.Quests, Pr.QuestsPerDay, today(), player.UserId)
	end)
	return reset
end

function Daily.snapshot(player: Player): any?
	local data = Data.get(player)
	if not data then
		return nil
	end
	local can, day, streak = D.status(data.daily, today())
	local ips = income(player, data)
	local tiles = {}
	for i, r in Pr.Daily do
		tiles[i] = if r.kind == "coins" then D.coins(r, ips) else 0
	end
	local quests = {}
	for i, q in data.quests.list do
		local def = D.questDef(Pr.Quests, q.id)
		if def then
			quests[i] = { id = q.id, text = def.text:format(def.goal), n = math.min(q.n, def.goal), goal = def.goal, claimed = q.claimed }
		end
	end
	return {
		canClaim = can,
		nextDay = day, -- the tile a claim would pay (or the last one paid)
		cycleDay = data.daily.cycleDay or 0,
		streak = if can then data.daily.streak or 0 else streak,
		newStreak = streak,
		tiles = tiles,
		quests = quests,
		questReward = D.coins(Pr.QuestReward, ips),
	}
end

local function readyFlag(player: Player, snap: any)
	local ready = snap.canClaim
	for _, q in snap.quests do
		if q.n >= q.goal and not q.claimed then
			ready = true
		end
	end
	player:SetAttribute("DailyReady", ready)
end

function Daily.send(player: Player)
	dirty[player] = nil
	local snap = Daily.snapshot(player)
	if snap then
		readyFlag(player, snap)
		Net.fire(player, "DailyState", snap)
	end
end

local function grantSquishy(player: Player, rarity: string): string
	local pool = S.ByRarity[rarity]
	local sp = pool[math.random(1, #pool)]
	Shelf.grant(player, sp.id, false)
	return sp.name
end

function Daily.claimDaily(player: Player): string?
	local data = Data.get(player)
	if not data then
		return nil
	end
	local can, day, streak = D.status(data.daily, today())
	if not can then
		return nil
	end
	local reward: any = Pr.Daily[day]
	local amount = if reward.kind == "coins" then D.coins(reward, income(player, data)) else 0
	Data.update(player, function(d)
		d.daily.lastClaimDay = today()
		d.daily.cycleDay = day
		d.daily.streak = streak
		if reward.kind == "sp" then
			d.sp += reward.amount
		end
	end)
	local text
	if reward.kind == "coins" then
		Economy.add(player, amount, "Daily")
		text = ("+%s coins"):format(Format.abbrev(amount))
	elseif reward.kind == "sp" then
		text = ("+%d Sling Power"):format(reward.amount)
	elseif reward.kind == "squishy" then
		text = "Free " .. grantSquishy(player, reward.rarity) .. "!"
	else
		local rarity = D.rollRarity(reward.odds, Z.Rarities, math.random())
		text = ("%s %s!"):format(rarity, grantSquishy(player, rarity))
	end
	Economy.refresh(player)
	Net.fire(player, "DailyClaimed", ("Day %d: %s"):format(day, text))
	Daily.send(player)
	return text
end

function Daily.claimQuest(player: Player, index: number): boolean
	ensureQuests(player)
	local data = Data.get(player)
	local q = data and data.quests.list[index]
	local def = q and D.questDef(Pr.Quests, q.id)
	if not data or not q or not def or q.claimed or q.n < def.goal then
		return false
	end
	local amount = D.coins(Pr.QuestReward, income(player, data))
	Data.update(player, function(d)
		d.quests.list[index].claimed = true
	end)
	Economy.add(player, amount, "Quest")
	Net.fire(player, "DailyClaimed", ("Quest done: +%s coins"):format(Format.abbrev(amount)))
	Daily.send(player)
	return true
end

-- quest progress from gameplay
function Daily.bump(player: Player, event: string, amount: number)
	local data = Data.get(player)
	if not data then
		return
	end
	ensureQuests(player)
	local moved: string? = nil
	Data.update(player, function(d)
		for _, q in d.quests.list do
			local def = D.questDef(Pr.Quests, q.id)
			if def and def.event == event and q.n < def.goal then
				q.n = math.min(def.goal, q.n + amount)
				if q.n >= def.goal then
					moved = def.text:format(def.goal)
				end
				dirty[player] = true
			end
		end
	end)
	if moved then
		Net.fire(player, "DailyClaimed", "Quest complete: " .. moved .. "! Claim it in Daily.")
		Daily.send(player)
	end
end

function Daily.start()
	Net.declare({ "DailyState", "DailyClaimed" })
	Net.on("ClaimDaily", { rate = 2, burst = 3 }, function(player)
		Daily.claimDaily(player)
	end)
	Net.on("ClaimQuest", { args = { "int" }, rate = 4 }, function(player, i)
		Daily.claimQuest(player, i)
	end)
	Net.on("DailyRequest", { rate = 2, burst = 3 }, function(player)
		Daily.send(player)
	end)
	for _, q in Pr.Quests do
		Progress.on(q.event, function(player: Player)
			Daily.bump(player, q.event, 1) -- one per event (merge events carry the size)
		end)
	end
	Data.onLoaded(function(player)
		ensureQuests(player)
		Daily.send(player)
	end)
	Dev.hooks.nextday = function(player: Player, n: number)
		dayOffset += if n == 0 then 1 else n
		Daily.send(player)
	end
	Players.PlayerRemoving:Connect(function(p)
		dirty[p] = nil
	end)
	-- flush quest progress once a second; roll the day over for players online at midnight
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(1)
			local dayChanged = today() ~= lastDay
			lastDay = today()
			for _, p in Players:GetPlayers() do
				if dayChanged or dirty[p] then
					if dayChanged then
						ensureQuests(p)
					end
					Daily.send(p)
				end
			end
		end
	end)
end

return Daily
