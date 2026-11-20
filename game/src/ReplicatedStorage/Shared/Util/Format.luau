--!strict
-- Number formatting: 1.2K, 3.45M ... Qi (DESIGN 7.1).
local Format = {}

local SUFFIX = { "K", "M", "B", "T", "Qa", "Qi" }

function Format.abbrev(n: number): string
	if n ~= n then
		return "0"
	end
	local neg = n < 0
	n = math.abs(n)
	local out: string
	if n < 1000 then
		if n == math.floor(n) then
			out = tostring(math.floor(n))
		else
			out = string.format("%.1f", n):gsub("%.0$", "")
		end
	else
		local i = 0
		while n >= 1000 and i < #SUFFIX do
			n /= 1000
			i += 1
		end
		local s = if n >= 100 then string.format("%d", math.floor(n)) elseif n >= 10 then string.format("%.1f", math.floor(n * 10) / 10) else string.format("%.2f", math.floor(n * 100) / 100)
		if string.find(s, ".", 1, true) then
			s = s:gsub("0+$", ""):gsub("%.$", "") -- 1.50 -> 1.5, 2.00 -> 2; never 270 -> 27
		end
		out = s .. SUFFIX[i]
	end
	return if neg then "-" .. out else out
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function Format.roman(n: number): string
	return ROMAN[n] or tostring(n)
end

return Format
