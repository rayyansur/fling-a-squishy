--!nonstrict
-- PipelineSync: rebuilds the latest pipeline build inside the open Studio place.
-- Installed once into ServerStorage of the Studio workbench place (never shipped).
--   require(game.ServerStorage.PipelineSync).sync("http://127.0.0.1:34872/studio")
-- Everything it creates is tagged "PipelineSynced"; the next sync removes it first, so
-- anything you add by hand in Studio stays put.
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")

local Sync = {}
Sync.VERSION = 4
local TAG = "PipelineSynced"

local function decode(v)
	if type(v) ~= "table" then
		return v
	end
	local k = v[1]
	if k == "V3" then
		return Vector3.new(v[2], v[3], v[4])
	elseif k == "V2" then
		return Vector2.new(v[2], v[3])
	elseif k == "CF" then
		return CFrame.new(table.unpack(v, 2, 13))
	elseif k == "C3" then
		return Color3.new(v[2], v[3], v[4])
	elseif k == "U2" then
		return UDim2.new(v[2], v[3], v[4], v[5])
	elseif k == "U" then
		return UDim.new(v[2], v[3])
	elseif k == "E" then
		local enumName = string.gsub(v[2], "^Enum%.", "")
		return Enum[enumName][v[3]]
	elseif k == "NR" then
		return NumberRange.new(v[2], v[3])
	elseif k == "NS" then
		local pts = {}
		for _, p in v[2] do
			table.insert(pts, NumberSequenceKeypoint.new(p[1], p[2], p[3]))
		end
		return NumberSequence.new(pts)
	elseif k == "CS" then
		local pts = {}
		for _, p in v[2] do
			table.insert(pts, ColorSequenceKeypoint.new(p[1], Color3.new(p[2], p[3], p[4])))
		end
		return ColorSequence.new(pts)
	elseif k == "F" then
		return Font.new(v[2], Enum.FontWeight[v[3]], Enum.FontStyle[v[4]])
	elseif k == "RC" then
		return Rect.new(v[2], v[3], v[4], v[5])
	elseif k == "PP" then
		return PhysicalProperties.new(v[2], v[3], v[4], v[5], v[6])
	elseif k == "CT" then
		return v[2]
	end
	return nil
end

local function resolveParent(spec, byId)
	if type(spec) == "number" then
		return byId[spec]
	end
	local svcName, child = string.match(spec, "^(%w+)%.(%w+)$")
	if svcName then
		return game:GetService(svcName):FindFirstChildOfClass(child)
	end
	return game:GetService(spec)
end

local meshCache = {}

local function create(row)
	if row.c == "MeshPart" and row.mesh and row.mesh ~= "" then
		-- MeshId isn't writable from here, so ask Roblox for a MeshPart of that mesh (cached)
		local template = meshCache[row.mesh]
		if template == nil then
			local ok, mp = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromUri(row.mesh))
			end)
			template = ok and mp or false
			meshCache[row.mesh] = template
		end
		if template then
			local mp = template:Clone()
			if row.texture then
				pcall(function()
					mp.TextureContent = Content.fromUri(row.texture)
				end)
			end
			return mp
		end
	end
	local inst = Instance.new(row.c)
	-- Decals and Textures: the image comes as TextureContent (Lune's name for it)
	if row.texture and inst:IsA("Decal") then
		pcall(function()
			(inst :: any).TextureContent = Content.fromUri(row.texture)
		end)
	end
	return inst
end

function Sync.clear()
	local n = 0
	for _, inst in CollectionService:GetTagged(TAG) do
		if inst.Parent then
			inst:Destroy()
			n += 1
		end
	end
	return n
end

function Sync.sync(baseUrl: string)
	local t0 = os.clock()
	local manifest = HttpService:JSONDecode(HttpService:GetAsync(baseUrl .. "/manifest.json", true))
	local removed = Sync.clear()
	task.wait()
	-- service-level settings (lighting, player settings, ...)
	for svcName, props in manifest.services or {} do
		local svc = game:GetService(svcName)
		for name, val in props do
			pcall(function()
				svc[name] = decode(val)
			end)
		end
	end
	local byId = {}
	local refs = {}
	local created, failedProps = 0, 0
	for i = 1, manifest.chunks do
		local rows = HttpService:JSONDecode(HttpService:GetAsync(("%s/chunk_%d.json"):format(baseUrl, i), true))
		local roots = {}
		for _, row in rows do
			local inst = create(row)
			inst.Name = row.n
			for name, val in row.p do
				if type(val) == "table" and val[1] == "R" then
					table.insert(refs, { inst, name, val[2] })
				else
					local ok = pcall(function()
						inst[name] = decode(val)
					end)
					if not ok then
						failedProps += 1
					end
				end
			end
			for k, v in row.a or {} do
				pcall(function()
					inst:SetAttribute(k, decode(v))
				end)
			end
			for _, tag in row.t or {} do
				inst:AddTag(tag)
			end
			byId[row.id] = inst
			local parent = resolveParent(row.parent, byId)
			if type(row.parent) == "number" and byId[row.parent] and byId[row.parent].Parent == nil then
				inst.Parent = parent -- still building that subtree off-DataModel
			else
				inst:AddTag(TAG)
				table.insert(roots, { inst, parent })
			end
			created += 1
		end
		-- parent this chunk's roots into the DataModel, a few at a time
		for _, r in roots do
			r[1].Parent = r[2]
		end
		task.wait()
	end
	for _, r in refs do
		pcall(function()
			r[1][r[2]] = byId[r[3]]
		end)
	end
	return ("synced build %s: %d instances (removed %d old, %d props skipped) in %.1fs"):format(
		manifest.build, created, removed, failedProps, os.clock() - t0)
end

return Sync
