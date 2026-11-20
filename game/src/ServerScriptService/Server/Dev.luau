--!strict
-- Studio-only test commands (DESIGN 15.5, 15.11): set SP, add coins, force Goo Rain, grant a
-- squishy. The remote is never created outside Studio.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local Economy = require(script.Parent.Economy)
local Shelf = require(script.Parent.Shelf)

local Dev = {}
Dev.hooks = {} :: { [string]: (Player, number) -> () }

function Dev.run(player: Player, cmd: string, value: number, text: string?)
	if cmd == "sp" then
		Data.update(player, function(d)
			d.sp = math.max(1, value)
		end)
	elseif cmd == "coins" then
		Economy.add(player, value, "Dev")
	elseif cmd == "grant" and text and Config.Squishies.ById[text] then
		Shelf.grant(player, text, value == 1)
	elseif cmd == "tutorial" then
		Data.update(player, function(d)
			d.tutorialDone = value == 0
			d.tutorialFlings = 0
		end)
		player:SetAttribute("TutorialStep", if value == 0 then 0 else 1)
	elseif Dev.hooks[cmd] then
		Dev.hooks[cmd](player, value)
	end
	Economy.refresh(player)
end

function Dev.start()
	if not RunService:IsStudio() then
		return
	end
	Net.on("Dev", { args = { "string", "number", "string" }, rate = 10, maxString = 40 }, function(player, cmd, value, text)
		Dev.run(player, cmd, value, text)
	end)
end

return Dev
