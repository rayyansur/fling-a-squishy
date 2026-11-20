--!nocheck
-- Re-opens the built place and checks generic structure + the performance budget
-- from pipeline.json. Game-specific structure belongs in tests/cloud/*.test.luau.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local config = serde.decode("json", fs.readFile("pipeline.json"))
local budget = config.budget or {}
local game = roblox.deserializePlace(fs.readFile(config.placeFile or "out/Game.rbxlx"))

local problems, warnings = {}, {}
local function fail(msg)
	table.insert(problems, msg)
end

local counts = { parts = 0, lights = 0, emitters = 0, scripts = 0, meshes = 0, placeholders = 0 }
for _, d in game:GetDescendants() do
	if d:IsA("BasePart") then
		counts.parts += 1
		if d:IsA("MeshPart") then
			counts.meshes += 1
		end
		if d:GetAttribute("PendingArt") then
			counts.placeholders += 1
			table.insert(warnings, ("art '%s' not uploaded yet (placeholder in the map)"):format(d:GetAttribute("PendingArt")))
		end
		if d.Size.X <= 0 or d.Size.Y <= 0 or d.Size.Z <= 0 then
			fail("zero-size part: " .. d:GetFullName())
		end
	elseif d:IsA("Light") then
		counts.lights += 1
	elseif d:IsA("ParticleEmitter") then
		counts.emitters += 1
	elseif d:IsA("LuaSourceContainer") then
		counts.scripts += 1
		if #d.Source < 10 then
			fail("empty script: " .. d:GetFullName())
		end
		if d:IsA("LocalScript") then
			local okParent = d:FindFirstAncestorOfClass("StarterPlayerScripts") or d:FindFirstAncestorOfClass("StarterCharacterScripts")
				or d:FindFirstAncestorOfClass("StarterGui") or d:FindFirstAncestorOfClass("ReplicatedFirst") or d:FindFirstAncestorOfClass("StarterPack")
			if not okParent then
				fail("LocalScript in a place where it never runs: " .. d:GetFullName())
			end
		elseif d:IsA("Script") and d.ClassName == "Script" then
			if d:FindFirstAncestorOfClass("ReplicatedStorage") or d:FindFirstAncestorOfClass("StarterPlayer") then
				fail("server Script in a place where it never runs: " .. d:GetFullName())
			end
		end
	end
end

if not game:GetService("Workspace"):FindFirstChildWhichIsA("SpawnLocation", true) then
	table.insert(warnings, "no SpawnLocation: players will spawn at the origin")
end

-- game/monetization.json (GUIDELINES: 2-4 passes and 2-4 developer products)
if fs.isFile("game/monetization.json") then
	local m = serde.decode("json", fs.readFile("game/monetization.json"))
	local keys = {}
	for _, kind in { "passes", "products" } do
		local n = 0
		for key, item in m[kind] or {} do
			n += 1
			local where = ("monetization.json %s.%s"):format(kind, key)
			if not key:match("^[a-z][a-z0-9_]*$") then
				fail(where .. ": keys are lower_snake_case")
			end
			if keys[key] then
				fail(where .. ": key used for both a pass and a product")
			end
			keys[key] = true
			if type(item.name) ~= "string" or #item.name < 3 or #item.name > 50 then
				fail(where .. ": name must be 3-50 characters")
			end
			if type(item.price) ~= "number" or item.price < 1 or item.price ~= math.floor(item.price) then
				fail(where .. ": price must be a whole number of Robux >= 1")
			end
			if item.description ~= nil and (type(item.description) ~= "string" or #item.description > 1000) then
				fail(where .. ": description must be a string up to 1000 characters")
			end
			if item.icon ~= nil and not fs.isFile(item.icon) then
				fail(where .. ": icon file " .. tostring(item.icon) .. " not found")
			end
		end
		if n > 4 then
			fail(("monetization.json: %d %s (GUIDELINES: at most 4)"):format(n, kind))
		elseif n < 2 then
			table.insert(warnings, ("monetization.json: %d %s (GUIDELINES: 2-4 per game)"):format(n, kind))
		end
	end
end

for k, limit in budget do
	if counts[k] and counts[k] > limit then
		fail(("%s budget exceeded: %d > %d"):format(k, counts[k], limit))
	end
end

print(("place: %d parts (%d meshes), %d lights, %d emitters, %d scripts"):format(counts.parts, counts.meshes, counts.lights, counts.emitters, counts.scripts))
for _, w in warnings do
	print("WARN  " .. w)
end
if #problems > 0 then
	for _, p in problems do
		print("FAIL  " .. p)
	end
	process.exit(1)
end
print("structure check passed")
