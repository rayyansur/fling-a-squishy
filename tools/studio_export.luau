--!nocheck
-- Exports the built place as JSON chunks that tools/studio/PipelineSync.luau rebuilds
-- inside an already-open Studio place (no file reopen, no "save changes?" prompts).
--
--   lune run tools/studio_export.luau [outDir]      default outDir: out/studio
-- Writes <outDir>/manifest.json and <outDir>/chunk_<n>.json (~1500 instances each).
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local config = serde.decode("json", fs.readFile("pipeline.json"))
local outDir = process.args[1] or "out/studio"
local db = roblox.getReflectionDatabase()
local game = roblox.deserializePlace(fs.readFile(config.placeFile or "out/Game.rbxlx"))

local CHUNK = 1500

-- properties Studio sets itself, can't be written from Luau, or are aliases
local SKIP = {
	Parent = true, Name = true, ClassName = true, Archivable = true,
	PhysicsData = true, MeshID = true, InitialSize = true, SolidMeshHolder = true, AlternateMeshHash = true,
	VertexCount = true, HasJointOffset = true, HasSkinnedMesh = true, JointOffset = true, RenderFidelityReplicate = true,
	MeshContent = true, TextureContent = true, LinkedSource = true, ScriptGuid = true, SourceAssetId = true,
	Tags = true, Attributes = true, AttributesSerialize = true, DefinesCapabilities = true, Capabilities = true,
	UniqueId = true, HistoryId = true, TimeOfDay = true, Origin = true,
	PivotOffset = true, WorldPivotData = true, ModelMeshCFrame = true, ModelMeshData = true, ModelMeshSize = true,
	NeedsPivotMigration = true, LevelOfDetail = true, ModelStreamingMode = true, ScaleFactor = true,
	BrickColor = true, Color3uint8 = true, size = true, formFactorRaw = true, shape = true,
	Font = true, FontSize = true, Style = true, TextColor = true, Velocity = true, RotVelocity = true,
	AssemblyLinearVelocity = true, AssemblyAngularVelocity = true, CollisionGroupId = true,
}

-- aliases of CFrame on parts and attachments (CFrame is synced instead); on GUI objects,
-- gradients and the rest they're real properties and must sync
local CFRAME_ALIASES = { Position = true, Orientation = true, Rotation = true }
local CFRAME_OWNERS = { BasePart = true, Attachment = true }

local function classProps(className)
	local list = {}
	local cls = db:GetClass(className)
	while cls do
		for name, prop in cls.Properties do
			local alias = CFRAME_ALIASES[name] and CFRAME_OWNERS[cls.Name]
			if not SKIP[name] and not alias and prop.Scriptability ~= "None" and prop.Scriptability ~= "Custom" then
				list[name] = prop
			end
		end
		cls = cls.Superclass and db:GetClass(cls.Superclass) or nil
	end
	return list
end

local propCache = {}
local defaultCache = {}

local refIds = {}
local nextRef = 0
local function refId(inst)
	if not refIds[inst] then
		nextRef += 1
		refIds[inst] = nextRef
	end
	return refIds[inst]
end

local function encode(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	elseif t == "Vector3" then
		return { "V3", v.X, v.Y, v.Z }
	elseif t == "Vector2" then
		return { "V2", v.X, v.Y }
	elseif t == "CFrame" then
		return { "CF", v:GetComponents() }
	elseif t == "Color3" then
		return { "C3", v.R, v.G, v.B }
	elseif t == "UDim2" then
		return { "U2", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then
		return { "U", v.Scale, v.Offset }
	elseif t == "EnumItem" then
		return { "E", tostring(v.EnumType), v.Name }
	elseif t == "NumberRange" then
		return { "NR", v.Min, v.Max }
	elseif t == "NumberSequence" then
		local k = {}
		for _, p in v.Keypoints do
			table.insert(k, { p.Time, p.Value, p.Envelope })
		end
		return { "NS", k }
	elseif t == "ColorSequence" then
		local k = {}
		for _, p in v.Keypoints do
			table.insert(k, { p.Time, p.Value.R, p.Value.G, p.Value.B })
		end
		return { "CS", k }
	elseif t == "Font" then
		return { "F", v.Family, v.Weight.Name, v.Style.Name }
	elseif t == "Rect" then
		return { "RC", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y }
	elseif t == "PhysicalProperties" then
		return { "PP", v.Density, v.Friction, v.Elasticity, v.FrictionWeight, v.ElasticityWeight }
	elseif t == "Instance" then
		return { "R", refId(v) }
	elseif t == "Content" then
		local uri = tostring(v):match("Uri=([^%)]+)")
		if uri and uri ~= "" then
			return { "CT", uri }
		end
		return nil
	end
	return nil -- unsupported type: skipped
end

local function same(a, b)
	if typeof(a) ~= typeof(b) then
		return false
	end
	if typeof(a) == "number" then
		return math.abs(a - b) < 1e-6
	end
	local ok, eq = pcall(function()
		return a == b
	end)
	return ok and eq
end

local function defaultsFor(className)
	if defaultCache[className] ~= nil then
		return defaultCache[className]
	end
	local ok, inst = pcall(roblox.Instance.new, className)
	defaultCache[className] = ok and inst or false
	return defaultCache[className]
end

local function serialize(inst, full)
	local className = inst.ClassName
	local props = propCache[className]
	if not props then
		props = classProps(className)
		propCache[className] = props
	end
	local def = defaultsFor(className)
	local node = { c = className, n = inst.Name, p = {} }
	for name in props do
		local ok, v = pcall(function()
			return inst[name]
		end)
		if ok and v ~= nil then
			local dok, dv = false, nil
			if def then
				dok, dv = pcall(function()
					return def[name]
				end)
			end
			if full or not (dok and same(v, dv)) then
				local e = encode(v)
				if e ~= nil then
					node.p[name] = e
				end
			end
		end
	end
	-- scripts and meshes: always carry the essentials
	if inst:IsA("LuaSourceContainer") then
		node.p.Source = inst.Source
	end
	if className == "Decal" or className == "Texture" then
		-- Lune keeps a decal's or texture's image in TextureContent (skipped above)
		local ok, c = pcall(function()
			return inst.TextureContent
		end)
		local uri = ok and c and tostring(c):match("Uri=([^%)]+)")
		if uri and uri ~= "" then
			node.texture = uri
		end
	end
	if className == "MeshPart" then
		-- Lune keeps mesh/texture ids in MeshContent/TextureContent
		for _, pair in { { "MeshContent", "mesh" }, { "TextureContent", "texture" } } do
			local ok, c = pcall(function()
				return inst[pair[1]]
			end)
			local uri = ok and c and tostring(c):match("Uri=([^%)]+)")
			if uri and uri ~= "" then
				node[pair[2]] = uri
			end
		end
	end
	local attrs = inst:GetAttributes()
	if next(attrs) then
		node.a = {}
		for k, v in attrs do
			node.a[k] = encode(v)
		end
	end
	local tags = inst:GetTags()
	if #tags > 0 then
		node.t = tags
	end
	return node
end

-- Flatten: every instance becomes a row {id, parent(id|service), node}
local rows = {}
local SERVICES = { "Workspace", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Teams" }
local serviceProps = {}

local function walk(inst, parentRef)
	local id = refId(inst)
	local node = serialize(inst)
	node.id = id
	node.parent = parentRef
	table.insert(rows, node)
	for _, child in inst:GetChildren() do
		walk(child, id)
	end
end

for _, svcName in SERVICES do
	local ok, svc = pcall(function()
		return game:GetService(svcName)
	end)
	if ok and svc then
		-- full: write every setting so the previous game's lighting etc. never leaks into this one
		local s = serialize(svc, svcName == "Lighting")
		for k, v in s.p do
			if type(v) == "table" and v[1] == "R" then
				s.p[k] = nil -- e.g. Workspace.CurrentCamera: Studio owns these
			end
		end
		serviceProps[svcName] = s.p
		for _, child in svc:GetChildren() do
			if not (child:IsA("Terrain") or child:IsA("Camera")) then
				if svcName == "StarterPlayer" and (child.ClassName == "StarterPlayerScripts" or child.ClassName == "StarterCharacterScripts") then
					-- these containers already exist in Studio: sync their children
					for _, g in child:GetChildren() do
						walk(g, "StarterPlayer." .. child.ClassName)
					end
				else
					walk(child, svcName)
				end
			end
		end
	end
end

-- write chunks
if fs.isDir(outDir) then
	fs.removeDir(outDir)
end
fs.writeDir(outDir)
local chunks = 0
for i = 1, #rows, CHUNK do
	chunks += 1
	local slice = table.move(rows, i, math.min(i + CHUNK - 1, #rows), 1, {})
	fs.writeFile(("%s/chunk_%d.json"):format(outDir, chunks), serde.encode("json", slice))
end
local buildId = tostring(os.time())
fs.writeFile(outDir .. "/manifest.json", serde.encode("json", {
	build = buildId,
	name = config.name,
	chunks = chunks,
	instances = #rows,
	services = serviceProps,
}))
print(("studio export: %d instances in %d chunks → %s (build %s)"):format(#rows, chunks, outDir, buildId))
