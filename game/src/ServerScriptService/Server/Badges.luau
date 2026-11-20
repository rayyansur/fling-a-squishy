--!strict
-- Badges (DESIGN 4.13). Ids live in Config.Badges; 0 = skip silently. Awarded from Progress
-- events; each award is tried once per session and pcall-wrapped (BadgeService can fail).
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ServerScriptService.Kit.Data)
local Progress = require(script.Parent.Progress)

local Ids = Config.Badges :: { [string]: number }
local Badges = {}
local tried: { [Player]: { [string]: boolean } } = {}

function Badges.award(player: Player, key: string)
	local id = Ids[key]
	if not id or id == 0 then
		return
	end
	local mine = tried[player]
	if not mine then
		mine = {}
		tried[player] = mine
	end
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end
	end)
end

function Badges.start()
	local RARITY_BADGE = { [3] = "first_rare", [4] = "first_epic", [5] = "first_legendary", [6] = "first_mythic" }
	Progress.on("catch", function(player: Player, ri: number, glitter: boolean)
		for r = 3, math.min(ri, 6) do
			Badges.award(player, RARITY_BADGE[r])
		end
		if glitter then
			Badges.award(player, "glitter")
		end
	end)
	Progress.on("triple", function(player: Player)
		Badges.award(player, "triple_bounce")
	end)
	Progress.on("merge", function(player: Player, size: number)
		Badges.award(player, if size >= 3 then "first_mega" else "first_chonky")
	end)
	Progress.on("zone", function(player: Player, zone: number)
		if zone >= 6 then
			Badges.award(player, "rainbow_rim")
		end
	end)
	Progress.on("slots", function(player: Player, slots: number)
		if slots >= Config.Economy.Slots.max then
			Badges.award(player, "full_shelf")
		end
	end)
	Progress.on("resquish", function(player: Player)
		Badges.award(player, "first_resquish")
	end)
	Progress.on("dex", function(player: Player, caught: number)
		if caught >= #Config.Squishies.List then
			Badges.award(player, "dex_complete")
		end
	end)
	Data.onLoaded(function(player)
		Badges.award(player, "welcome")
	end)
	Players.PlayerRemoving:Connect(function(p)
		tried[p] = nil
	end)
end

return Badges
