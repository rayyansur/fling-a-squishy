--!strict
-- Shared tuning values for this game: prices, timings, rewards. Passes and developer products are
-- declared in game/monetization.json (CI creates them and fills in the ids).
local Config = {}

-- Kit.Data: what a new player's save looks like (see kit/ServerScriptService/Kit/Data.luau)
Config.Data = {
	store = "PlayerData_v1",
	defaults = {},
	mirror = {}, -- keys copied to Player attributes for client UI
	leaderstats = {},
}

-- Kit.UI colours + font (see kit/ReplicatedStorage/Kit/Types.luau Theme); set per game
Config.Theme = {}

return Config
