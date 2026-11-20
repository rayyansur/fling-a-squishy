--!nocheck
-- Places meshes made in Blender (art/models/*.py) into the map.
--
-- art/assets.lock.json is written by CI after it uploads each FBX to Roblox:
--   { "<model>": { "sha256": "...", "assetId": "123", "parts": [
--       { "name": "Body", "meshId": "rbxassetid://...", "textureId": "", "size": [x,y,z],
--         "offset": [12 CFrame components relative to the model pivot], "color": "#rrggbb",
--         "material": "SmoothPlastic", "transparency": 0 } ] } }
--
-- Until a model has been uploaded (no lock entry yet), place() builds a labelled
-- placeholder box of the right size so the map still builds and tests still run.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Assets = {}
Assets.__index = Assets

function Assets.new(B, lockPath)
	local self = setmetatable({ B = B, lock = {}, placed = 0, missing = {} }, Assets)
	if fs.isFile(lockPath) then
		self.lock = serde.decode("json", fs.readFile(lockPath))
	end
	-- the art build writes bounding sizes even before upload, for placeholders
	if fs.isFile("art/out/manifest.json") then
		self.manifest = serde.decode("json", fs.readFile("art/out/manifest.json"))
	else
		self.manifest = {}
	end
	return self
end

function Assets:has(name)
	local e = self.lock[name]
	return e ~= nil and e.parts ~= nil and #e.parts > 0
end

-- place(parent, name, cf, { scale = 1, anchored = true, collide = true })
-- returns a Model named `name` with MeshParts (or a placeholder)
function Assets:place(parent, name, cf, opts)
	opts = opts or {}
	local B = self.B
	local V3, CF = B.V3, B.CF
	local scale = opts.scale or 1
	local model = B.model(parent, name)
	model:SetAttribute("ArtModel", name)
	local entry = self.lock[name]
	if entry and entry.parts and #entry.parts > 0 then
		-- Models are authored in Blender with 1 unit = 1 stud. Roblox's importer may
		-- rescale on upload, so fit the uploaded size back to the authored size.
		local m = self.manifest[name]
		if m and entry.bounds and entry.bounds[2] > 0 then
			scale *= m.size[2] / entry.bounds[2]
		end
		for _, p in entry.parts do
			local mp = B.I.new("MeshPart")
			mp.Name = p.name or name
			mp.MeshId = p.meshId
			if p.textureId and p.textureId ~= "" then
				mp.TextureID = p.textureId
			end
			local size = V3.new(p.size[1], p.size[2], p.size[3])
			mp.InitialSize = size
			mp.Size = size * scale
			local off = p.offset and CF.new(table.unpack(p.offset)) or CF.new()
			local scaledOff = CF.new(off.Position * scale) * (off - off.Position)
			mp.CFrame = cf * scaledOff
			mp.Anchored = if opts.anchored == nil then true else opts.anchored
			mp.CanCollide = if opts.collide == nil then true else opts.collide
			if p.color then
				mp.Color = B.hex(p.color)
			end
			if p.material then
				mp.Material = B.E.Material[p.material]
			end
			if p.transparency and p.transparency > 0 then
				mp.Transparency = p.transparency
			end
			mp.Parent = model
			B.partCount += 1
		end
		model:SetAttribute("AssetId", entry.assetId)
		self.placed += 1
	else
		local m = self.manifest[name]
		local size = m and V3.new(m.size[1], m.size[2], m.size[3]) or V3.new(2, 2, 2)
		local p = B.part(model, { name = "Placeholder", size = size * scale, cf = cf * CF.new(0, size.Y * scale / 2, 0), color = "#ff3d9a", mat = "SmoothPlastic", t = 0.35 })
		p:SetAttribute("PendingArt", name)
		table.insert(self.missing, name)
	end
	return model
end

return Assets
