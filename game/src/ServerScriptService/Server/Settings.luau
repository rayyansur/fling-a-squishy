--!strict
-- Settings (DESIGN 7.3.7): Music, SFX, Low Graphics, saved and mirrored to attributes
-- (SetMusic / SetSfx / SetLow) that the client reads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)

local Settings = {}

local function mirror(player: Player)
	local d = Data.get(player)
	if d then
		player:SetAttribute("SetMusic", d.settings.music)
		player:SetAttribute("SetSfx", d.settings.sfx)
		player:SetAttribute("SetLow", d.settings.lowGraphics)
	end
end

function Settings.start()
	Net.on("SettingsSave", { args = { "boolean", "boolean", "boolean" }, rate = 4 }, function(player, music, sfx, low)
		Data.update(player, function(d)
			d.settings.music, d.settings.sfx, d.settings.lowGraphics = music, sfx, low
		end)
		mirror(player)
	end)
	Data.onLoaded(mirror)
end

return Settings
