--!strict
-- Goo Rain (DESIGN 4.10): every 12 min of uptime from minute 4, 90 s of distance x1.25, Rare+
-- luck x2 and double hop speed. Publishes the current/next window on ReplicatedStorage as server
-- times (GooRainStart / GooRainEnd); clients run the banner, decor, tint and music from those.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Schedule = require(ReplicatedStorage.Shared.Util.GooRain)
local Fling = require(script.Parent.Fling)
local Dev = require(script.Parent.Dev)

local cfg = Config.Progress.GooRain
local GooRain = {}

local forced: Schedule.Window? = nil

local function uptime(): number
	return workspace.DistributedGameTime
end

function GooRain.window(): Schedule.Window
	local u = uptime()
	if forced and u < forced.finish then
		return forced
	end
	return Schedule.window(u, cfg)
end

function GooRain.active(): boolean
	local w = GooRain.window()
	local u = uptime()
	return u >= w.start and u < w.finish
end

-- start one now (Studio Dev command); the regular schedule carries on afterwards
function GooRain.force()
	local u = uptime()
	forced = { start = u, finish = u + cfg.Duration }
end

local function publish()
	local w = GooRain.window()
	local offset = workspace:GetServerTimeNow() - uptime()
	local s, f = math.floor((offset + w.start) * 10) / 10, math.floor((offset + w.finish) * 10) / 10
	-- only republish when the window really moved (clock drift is a few ms)
	local old = ReplicatedStorage:GetAttribute("GooRainStart") :: number?
	if not old or math.abs(old - s) > 0.5 then
		ReplicatedStorage:SetAttribute("GooRainStart", s)
		ReplicatedStorage:SetAttribute("GooRainEnd", f)
	end
	ReplicatedStorage:SetAttribute("GooRainActive", GooRain.active())
end

function GooRain.start()
	Fling.gooRain = GooRain.active
	Dev.hooks.goorain = function()
		GooRain.force()
		publish()
	end
	publish()
	task.spawn(function()
		while true do
			task.wait(0.5)
			publish()
		end
	end)
end

return GooRain
