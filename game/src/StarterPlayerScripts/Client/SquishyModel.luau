--!strict
-- Builds a squishy Model from the templates in ReplicatedStorage.Assets: the species' body
-- (recoloured "Body" part + the shared face), its accessory, size scale, Glitter sparkle.
-- Bodies and accessories share one Pin bounding box, so they line up at the same pivot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Mod = require(ReplicatedStorage.Shared.Util.Modifier)
local S, Z = Config.Squishies, Config.Zones

local SquishyModel = {}

-- studs: a Normal squishy at species scale 1 is about this wide
SquishyModel.BASE_WIDTH = 2

local assets = ReplicatedStorage:WaitForChild("Assets")
local rainbowParts: { BasePart } = {}

local function template(folder: string, name: string): Model?
	local f = assets:FindFirstChild(folder)
	return f and f:FindFirstChild(name) :: Model?
end

local function stripPins(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Pin" then
			d:Destroy()
		end
	end
end

local FX = {
	stars = { color = Color3.fromHex("#FFF6A8"), rate = 4, size = 0.25 },
	embers = { color = Color3.fromHex("#FF8A3D"), rate = 6, size = 0.2 },
	prism = { color = Color3.fromHex("#FFFFFF"), rate = 6, size = 0.3 },
	nebula = { color = Color3.fromHex("#B78CFF"), rate = 5, size = 0.35 },
	glitter = { color = Color3.fromHex("#FFFFFF"), rate = 5, size = 0.22 },
	galactic = { color = Color3.fromHex("#C9B8FF"), rate = 10, size = 0.3 },
	giant = { color = Color3.fromHex("#FFD23F"), rate = 3, size = 0.35 },
}

local function sparkle(parent: BasePart, kind: string)
	local f = FX[kind]
	if not f then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(f.color)
	pe.Size = NumberSequence.new(f.size)
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Rate = f.rate
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.8
	pe.Parent = parent
end

-- height of a squishy model in studs (for billboards / pops)
function SquishyModel.height(speciesId: string, size: number, mod: string?): number
	local sp = S.ById[speciesId]
	return 2 * (sp and sp.scale or 1) * S.SizeScale[size or 1] * Mod.scale(Z, mod)
end

function SquishyModel.width(speciesId: string, size: number, mod: string?): number
	local sp = S.ById[speciesId]
	return SquishyModel.BASE_WIDTH * (sp and sp.scale or 1) * S.SizeScale[size or 1] * Mod.scale(Z, mod)
end

-- a see-through shell just outside the body (Shiny rim, Galactic force field)
local function shell(root: BasePart, model: Model, name: string, material: Enum.Material, color: Color3, t: number, grow: number)
	local rim = root:Clone()
	rim:ClearAllChildren()
	rim.Name = name
	rim.Material = material
	rim.Color = color
	rim.Transparency = t
	rim.Size = root.Size * grow
	rim.CFrame = root.CFrame
	rim.Parent = model
end

-- returns an anchored, non-colliding Model pivoted at its base centre
function SquishyModel.build(speciesId: string, size: number?, glitter: boolean?, mod: string?): Model
	mod = Mod.clean(Z, mod)
	local sp = S.ById[speciesId] or S.List[1]
	local model = Instance.new("Model")
	model.Name = sp.id
	local body = template("Bodies", "body_" .. sp.body)
	local root: BasePart? = nil
	if body then
		for _, c in body:GetChildren() do
			if c:IsA("BasePart") then
				local p = c:Clone()
				if p.Name == "Body" or p.Name == "Placeholder" then
					p.Color = if mod == "galactic" then Color3.fromHex("#3A2A8C") else Color3.fromHex(sp.color)
					if sp.mat then
						p.Material = (Enum.Material :: any)[sp.mat]
					end
					if sp.transparency then
						p.Transparency = sp.transparency
					end
					if sp.rainbow then
						table.insert(rainbowParts, p)
					end
					root = p
				end
				p.Parent = model
			end
		end
	end
	if sp.acc then
		local acc = template("Accessories", sp.acc)
		if acc then
			for _, c in acc:GetChildren() do
				if c:IsA("BasePart") and c.Name ~= "Placeholder" then
					c:Clone().Parent = model
				end
			end
		end
	end
	stripPins(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	if not root then
		root = model:FindFirstChildWhichIsA("BasePart")
	end
	if root then
		model.PrimaryPart = root
	end
	-- the templates are authored at scale 1 = BASE_WIDTH studs wide; pivot at the base
	local cf, bbox = model:GetBoundingBox()
	local base = cf * CFrame.new(0, -bbox.Y / 2, 0)
	-- with a PrimaryPart the model's pivot IS the primary part's pivot (WorldPivot is ignored),
	-- so set it through PivotOffset or everything sits half sunk into the shelf
	if root then
		root.PivotOffset = root.CFrame:ToObjectSpace(base)
	else
		model.WorldPivot = base
	end
	local s = (sp.scale or 1) * S.SizeScale[size or 1] * Mod.scale(Z, mod)
	if s ~= 1 and #model:GetChildren() > 0 then
		model:ScaleTo(s)
	end
	if root then
		if sp.fx then
			sparkle(root, sp.fx)
		end
		if glitter then
			sparkle(root, "glitter")
			shell(root, model, "GlitterRim", Enum.Material.Neon, Color3.fromHex("#FFF6A8"), 0.82, 1.06)
		end
		if mod == "galactic" then
			sparkle(root, "galactic")
			sparkle(root, "stars")
			shell(root, model, "GalaxyShell", Enum.Material.ForceField, Color3.fromHex("#9B7CFF"), 0, 1.12)
		elseif mod == "giant" then
			sparkle(root, "giant")
		end
	end
	model:SetAttribute("Mod", mod or "")
	model:SetAttribute("Species", sp.id)
	model:SetAttribute("Size", size or 1)
	return model
end

-- the Prism Blob body cycles through the rainbow
RunService.Heartbeat:Connect(function()
	if #rainbowParts == 0 then
		return
	end
	local c = Color3.fromHSV((os.clock() * 0.25) % 1, 0.55, 1)
	for i = #rainbowParts, 1, -1 do
		local p = rainbowParts[i]
		if p.Parent then
			p.Color = c
		else
			table.remove(rainbowParts, i)
		end
	end
end)

return SquishyModel
