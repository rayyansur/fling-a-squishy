--!nocheck
-- Validates out/props.json (from tools/props.py) against the Roblox reflection
-- database bundled with Lune. Exits non-zero on any unknown class/property.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local db = roblox.getReflectionDatabase()
local uses = serde.decode("json", fs.readFile("out/props.json"))
local bad = 0
for cls, props in uses do
	local c = db:GetClass(cls)
	if not c then
		print("UNKNOWN CLASS", cls)
		bad += 1
		continue
	end
	local set = {}
	local cur = c
	while cur do
		for name in cur.Properties do
			set[name] = true
		end
		cur = cur.Superclass and db:GetClass(cur.Superclass) or nil
	end
	for prop, where in props do
		if not set[prop] then
			print(("UNKNOWN PROPERTY %s.%s  (%s)"):format(cls, prop, where))
			bad += 1
		end
	end
end
if bad > 0 then
	print(("property check FAILED: %d problem(s)"):format(bad))
	process.exit(1)
end
print("property check passed")
