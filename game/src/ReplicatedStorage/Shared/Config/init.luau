--!strict
-- Every tunable number in the game (DESIGN.md section 13). The kit reads Config.Data and
-- Config.Theme; the game reads the child modules.
local Config = {}

Config.Game = require(script.Game)
Config.Map = require(script.Map)
Config.Zones = require(script.Zones)
Config.Squishies = require(script.Squishies)
Config.Economy = require(script.Economy)
Config.Monetization = require(script.Monetization)
Config.Audio = require(script.Audio)
Config.UI = require(script.UI)
Config.Badges = require(script.Badges)
Config.Progress = require(script.Progress)

-- Kit.Data: the save (DESIGN 6.4). Purchase receipts live in the kit's own record.
Config.Data = {
	store = "FAS_PlayerData_v1",
	autosaveSeconds = Config.Game.AutosaveInterval,
	defaults = {
		version = 1,
		coins = 0,
		sp = 1,
		goo = 1,
		gloves = 1,
		sling = 1,
		slotUpgrades = 0,
		shelfLevel = 1,
		reSquishes = 0,
		shelf = {}, -- { uid, s = speciesId, z = size 1..3, g = shiny, m = modifier? }
		inv = {}, -- same entries, off the shelf (earn nothing until equipped)
		dex = {}, -- [speciesId] = { n, best, glitter }
		autoMerge = true,
		daily = { lastClaimDay = 0, streak = 0, cycleDay = 0 },
		quests = { day = 0, list = {} },
		stats = {
			flings = 0,
			perfects = 0,
			bounces = 0,
			tripleBounces = 0,
			caught = 0,
			merges = 0,
			squeezes = 0,
			highestZone = 1,
			totalEarned = 0,
			playSeconds = 0,
		},
		tutorialDone = false,
		tutorialFlings = 0,
		settings = { music = true, sfx = true, lowGraphics = false },
		lastOnline = 0,
		lastIncomePerSec = 0,
		uidSeq = 0,
	},
	-- copied to Player attributes for the HUD
	mirror = { "coins", "sp", "goo", "gloves", "sling", "slotUpgrades", "shelfLevel", "reSquishes", "autoMerge", "tutorialDone" },
	leaderstats = {}, -- Squishies + Coins are made by the Economy module (Coins is abbreviated text)
}

Config.Theme = require(script.Parent.Theme).Kit

return Config
