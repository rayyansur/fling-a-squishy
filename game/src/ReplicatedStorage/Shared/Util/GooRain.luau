--!strict
-- Goo Rain schedule (DESIGN 4.10). Pure: uptime in seconds -> the current or next window.
local GooRain = {}

export type Window = { start: number, finish: number }

-- the window that is running at `uptime`, or the next one
function GooRain.window(uptime: number, cfg: any): Window
	local first, every, dur = cfg.First, cfg.Interval, cfg.Duration
	if uptime < first then
		return { start = first, finish = first + dur }
	end
	local k = (uptime - first) // every
	local s = first + k * every
	if uptime >= s + dur then
		s += every
	end
	return { start = s, finish = s + dur }
end

function GooRain.active(uptime: number, cfg: any): boolean
	local w = GooRain.window(uptime, cfg)
	return uptime >= w.start and uptime < w.finish
end

return GooRain
