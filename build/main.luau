--!nocheck
-- Generic place builder. Run from the repo root:  lune run build/main.luau
--
--   pipeline.json            game name, output path, budgets, Studio views
--   game/settings.luau       optional: function(ctx) that sets lighting/services
--   game/map/*.luau          each returns function(B, ctx) and builds part of the map
--   game/src/<Service>/...   scripts, Rojo-style names:
--                              X.server.luau -> Script, X.client.luau -> LocalScript,
--                              X.luau -> ModuleScript, folder -> Folder,
--                              folder/init(.server|.client).luau -> the folder IS that script
--   art/assets.lock.json     uploaded meshes (filled by CI), placed with ctx.Assets.place()
--   kit/<Service>/...        the shared runtime kit (Data, Shop, Net, UI ...), same layout
--   game/monetization.json   passes + products; with game/monetization.lock.json (ids per
--                            universe, filled by CI) it becomes ReplicatedStorage.Kit.Catalog
--   art/images/*.png (+.json) UI images and sprite sheets; with art/images.lock.json (filled by
--                            CI) they become ReplicatedStorage.Kit.Images (use Kit.Icon to show them)
--
-- Writes out/Game.rbxlx and out/sourcemap.json (for type checking).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local B = require("./lib/B")
local Assets = require("./lib/Assets")
local roblox = B.R
local I = B.I

local config = serde.decode("json", fs.readFile("pipeline.json"))

local game = I.new("DataModel")
local ws = game:GetService("Workspace")

local ctx = {
	game = game,
	workspace = ws,
	config = config,
	B = B,
	env = {
		Instance = roblox.Instance,
		CFrame = roblox.CFrame,
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Font = roblox.Font,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		NumberRange = roblox.NumberRange,
		Vector2 = roblox.Vector2,
	},
}
ctx.Assets = Assets.new(B, "art/assets.lock.json")

------------------------------------------------------------------ settings + map
if fs.isFile("game/settings.luau") then
	require("../game/settings")(ctx)
end

local mapFiles = {}
if fs.isDir("game/map") then
	for _, f in fs.readDir("game/map") do
		if f:match("%.luau$") then
			table.insert(mapFiles, f)
		end
	end
end
table.sort(mapFiles)
for _, f in mapFiles do
	local build = require("../game/map/" .. f:gsub("%.luau$", ""))
	build(B, ctx)
end

------------------------------------------------------------------ scripts (Rojo-style)
local SERVICE_PATHS = {
	StarterPlayerScripts = { "StarterPlayer", "StarterPlayerScripts" },
	StarterCharacterScripts = { "StarterPlayer", "StarterCharacterScripts" },
}

local function serviceFor(name)
	local path = SERVICE_PATHS[name]
	if not path then
		return game:GetService(name)
	end
	local parent = game:GetService(path[1])
	local child = parent:FindFirstChildOfClass(path[2])
	if not child then
		child = I.new(path[2])
		child.Parent = parent
	end
	return child
end

local sourcemapChildren = {}

local function scriptClass(file)
	if file:match("%.server%.luau$") then
		return "Script", file:gsub("%.server%.luau$", "")
	elseif file:match("%.client%.luau$") then
		return "LocalScript", file:gsub("%.client%.luau$", "")
	elseif file:match("%.luau$") then
		return "ModuleScript", file:gsub("%.luau$", "")
	end
	return nil
end

-- returns the instance plus its sourcemap node
local function buildEntry(dir, name, parent)
	local path = dir .. "/" .. name
	if fs.isDir(path) then
		local initFile
		for _, f in fs.readDir(path) do
			if f == "init.luau" or f == "init.server.luau" or f == "init.client.luau" then
				initFile = f
			end
		end
		local inst, node
		if initFile then
			local class = scriptClass(initFile)
			inst = I.new(class)
			inst.Source = fs.readFile(path .. "/" .. initFile)
			node = { name = name, className = class, filePaths = { path .. "/" .. initFile }, children = {} }
		else
			inst = I.new("Folder")
			node = { name = name, className = "Folder", children = {} }
		end
		inst.Name = name
		local kids = fs.readDir(path)
		table.sort(kids)
		for _, f in kids do
			if f ~= initFile then
				local child, cnode = buildEntry(path, f, inst)
				if child then
					table.insert(node.children, cnode)
				end
			end
		end
		inst.Parent = parent
		return inst, node
	end
	local class, base = scriptClass(name)
	if not class then
		return nil
	end
	local inst = I.new(class)
	inst.Name = base
	inst.Source = fs.readFile(path)
	inst.Parent = parent
	return inst, { name = base, className = class, filePaths = { path } }
end

-- kit/ first, then the game's own scripts; both use the same Rojo-style layout
local nodeBySvc = {}
for _, root in { "kit", "game/src" } do
	if fs.isDir(root) then
		local services = fs.readDir(root)
		table.sort(services)
		for _, svc in services do
			if fs.isDir(root .. "/" .. svc) and not (root == "kit" and svc == "tests") then
				local parent = serviceFor(svc)
				local node = nodeBySvc[svc]
				if not node then
					node = { name = svc, className = parent.ClassName, children = {} }
					nodeBySvc[svc] = node
					table.insert(sourcemapChildren, { service = svc, node = node })
				end
				local entries = fs.readDir(root .. "/" .. svc)
				table.sort(entries)
				for _, e in entries do
					local inst, cnode = buildEntry(root .. "/" .. svc, e, parent)
					if inst then
						table.insert(node.children, cnode)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------ monetization catalog
-- ReplicatedStorage.Kit.Catalog = game/monetization.json + the ids CI created per universe.
-- Written to out/ too so the type checker can follow requires into it.
local function luauValue(v, indent)
	local t = type(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local keys = {}
		for k in v do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local pad = string.rep("\t", indent + 1)
		local lines = {}
		for _, k in keys do
			local key = type(k) == "number" and ("[%d]"):format(k) or ("[%q]"):format(tostring(k))
			table.insert(lines, ("%s%s = %s,"):format(pad, key, luauValue(v[k], indent + 1)))
		end
		if #lines == 0 then
			return "{}"
		end
		return "{\n" .. table.concat(lines, "\n") .. "\n" .. string.rep("\t", indent) .. "}"
	end
	error("unsupported value in generated data: " .. tostring(v))
end

local monetization = { passes = {}, products = {} }
if fs.isFile("game/monetization.json") then
	monetization = serde.decode("json", fs.readFile("game/monetization.json"))
	monetization.passes = monetization.passes or {}
	monetization.products = monetization.products or {}
end
local monetizationIds = {}
if fs.isFile("game/monetization.lock.json") then
	for uni, e in serde.decode("json", fs.readFile("game/monetization.lock.json")) do
		monetizationIds[uni] = { passes = {}, products = {} }
		for kind in monetizationIds[uni] do
			for k, item in e[kind] or {} do
				monetizationIds[uni][kind][k] = item.id
			end
		end
	end
end
local kitShared = game:GetService("ReplicatedStorage"):FindFirstChild("Kit")
if kitShared then
	local catalogSource = "--!strict\n-- GENERATED by build/main.luau from game/monetization.json + game/monetization.lock.json.\n"
		.. "-- Edit those files, not this one.\n"
		.. "local Types = require(script.Parent.Types)\n\n"
		.. "local data: Types.CatalogData = {\n"
		.. "\tpasses = " .. luauValue(monetization.passes, 1) .. ",\n"
		.. "\tproducts = " .. luauValue(monetization.products, 1) .. ",\n"
		.. "\tids = " .. luauValue(monetizationIds, 1) .. ",\n"
		.. "}\n\nreturn data\n"
	fs.writeDir("out/kit")
	fs.writeFile("out/kit/Catalog.luau", catalogSource)
	local catalog = I.new("ModuleScript")
	catalog.Name = "Catalog"
	catalog.Source = catalogSource
	catalog.Parent = kitShared
	for _, node in nodeBySvc.ReplicatedStorage.children do
		if node.name == "Kit" then
			table.insert(node.children, { name = "Catalog", className = "ModuleScript", filePaths = { "out/kit/Catalog.luau" } })
		end
	end
end

------------------------------------------------------------------ images (Kit.Images)
-- { [image] = { id = "rbxassetid://..." | "", size = { w, h }?, sprites = { [name] = { x, y, w, h } }? } }
-- An image without a lock entry yet, or whose png changed since its upload (CI uploads it on
-- push), gets id = "": Kit.Icon draws nothing and games fall back to their emoji.
if kitShared then
	local imageLock = fs.isFile("art/images.lock.json") and serde.decode("json", fs.readFile("art/images.lock.json")) or {}
	local images = {}
	if fs.isDir("art/images") then
		for _, f in fs.readDir("art/images") do
			local name = f:match("^(.+)%.png$")
			if name then
				local e = imageLock[name]
				-- only trust the uploaded id while the png is the one that was uploaded: a re-packed
				-- sheet with the old id shows every sprite at the wrong crop (emoji fallback instead)
				local fresh = e ~= nil and (e.sha256 == nil or e.sha256 == serde.hash("sha256", fs.readFile("art/images/" .. f)))
				local entry = { id = fresh and e.imageId and ("rbxassetid://" .. e.imageId) or "" }
				local meta = "art/images/" .. name .. ".json"
				if fs.isFile(meta) then
					local m = serde.decode("json", fs.readFile(meta))
					entry.size = m.size
					entry.sprites = m.sprites
				end
				images[name] = entry
			end
		end
	end
	local imagesSource = "--!strict\n-- GENERATED by build/main.luau from art/images/*.png (+ .json sprite rects) and art/images.lock.json.\n"
		.. "-- Edit those files, not this one. Show them with Kit.Icon.\n"
		.. "local images: { [string]: { id: string, size: { number }?, sprites: { [string]: { number } }? } } = "
		.. luauValue(images, 0) .. "\n\nreturn images\n"
	fs.writeDir("out/kit")
	fs.writeFile("out/kit/Images.luau", imagesSource)
	local mod = I.new("ModuleScript")
	mod.Name = "Images"
	mod.Source = imagesSource
	mod.Parent = kitShared
	for _, node in nodeBySvc.ReplicatedStorage.children do
		if node.name == "Kit" then
			table.insert(node.children, { name = "Images", className = "ModuleScript", filePaths = { "out/kit/Images.luau" } })
		end
	end
end

------------------------------------------------------------------ sourcemap (luau-lsp)
-- Mirrors the built tree so `script.Parent.X` and game paths type-check.
local function mapInstance(inst, fileNode)
	local node = { name = inst.Name, className = inst.ClassName, children = {} }
	if fileNode and fileNode.filePaths then
		node.filePaths = fileNode.filePaths
	end
	local fileKids = {}
	if fileNode and fileNode.children then
		for _, c in fileNode.children do
			fileKids[c.name] = c
		end
	end
	for _, child in inst:GetChildren() do
		-- keep the map small: scripts, folders, models, values, remotes and named containers
		if not child:IsA("BasePart") or fileKids[child.Name] then
			table.insert(node.children, mapInstance(child, fileKids[child.Name]))
		end
	end
	return node
end

local root = { name = "Game", className = "DataModel", children = {} }
local fileBySvc = {}
for _, s in sourcemapChildren do
	fileBySvc[s.service] = s.node
end
for _, svc in { "Workspace", "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" } do
	local inst = game:GetService(svc)
	local fileNode = fileBySvc[svc]
	if svc == "StarterPlayer" then
		fileNode = { children = {} }
		for name in SERVICE_PATHS do
			if fileBySvc[name] then
				local n = fileBySvc[name]
				table.insert(fileNode.children, { name = name, children = n.children })
			end
		end
	end
	table.insert(root.children, mapInstance(inst, fileNode))
end

------------------------------------------------------------------ write
fs.writeDir("out")
local outPath = config.placeFile or "out/Game.rbxlx"
fs.writeFile(outPath, roblox.serializePlace(game, true))
fs.writeFile("out/sourcemap.json", serde.encode("json", root))

local parts, scripts = 0, 0
for _, d in game:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
print(("built %s → %s  (%d parts, %d scripts, %d meshes from art/)"):format(config.name or "game", outPath, parts, scripts, ctx.Assets.placed))
