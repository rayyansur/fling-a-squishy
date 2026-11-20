--!nocheck
-- Build-time config validation (DESIGN 13): same checks the server runs at boot.
local Shared = require("./lib/Shared")

return function(B, ctx)
	local Config = Shared("Config")
	local ConfigCheck = Shared("Util/ConfigCheck")
	local problems = ConfigCheck.run(Config)
	if #problems > 0 then
		error("Config validation failed:\n  " .. table.concat(problems, "\n  "))
	end
	print(("config valid: %d zones, %d squishies, %d jelly pads"):format(#Config.Zones.List, #Config.Squishies.List, #Config.Map.JellyPads))
end
