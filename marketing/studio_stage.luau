-- Stages the game page shots in the real map (Studio, execute_luau, Edit). Everything staged
-- goes in workspace.MarketingStage; nothing is saved (the workbench is rebuilt by every sync).
--   _G.avatar(cf, pose, lookAt?)      the real "bacon hair" avatar (catalog items below), posed
--   _G.squishy(id, size, cf, glitter) a squishy built by the game's own SquishyModel
--   _G.goo(pos, scale)                the game's goo blob
--   _G.pad(pos, scale, color?)        a jelly pad (the game's model)
--   _G.mask(true|false)               mask mode: every staged part flat white on black, the map
--                                     hidden (compose.py cuts the sticker outline from it)
--   _G.featured = { inst, ... }       map pieces that count as foreground in the mask (a slingshot)
--   _G.clear()                        deletes the stage
-- Capture each shot twice from the same camera (screen_capture camera_position/look_at_position):
-- once normally, once with _G.mask(true). One capture per turn.
-- The avatar: Pal Hair (63690008), Blue and Black Motorcycle Shirt (144076358), Dark Green Jeans
-- (144076760), the Robloxian 2.0 R15 body (bundle 311), white, the classic head and smile.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WHITE = Color3.fromRGB(242, 243, 243)

local SquishyModel = require(game.StarterPlayer.StarterPlayerScripts.Client.SquishyModel)
local Squishies = require(RS.Shared.Config).Squishies

local function A(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function stage(): Folder
	local st = workspace:FindFirstChild("MarketingStage")
	if not st then
		st = Instance.new("Folder")
		st.Name = "MarketingStage"
		st.Parent = workspace
	end
	return st
end

local function fk(m, parentName, childName, attName, rot)
	local p, c = m[parentName], m[childName]
	c.CFrame = p.CFrame * p[attName].CFrame * rot * c[attName].CFrame:Inverse()
end

-- poses: shoulder, elbow per side (s = +1 right, -1 left; Z>0 swings the arm outward)
local POSES = {
	pull = { -- both hands at the chest, drawing the pouch back; leaning back on the right leg
		arm = function(s)
			return A(80, 0, -s * 28), A(70, 0, 0)
		end,
		leg = function(s)
			if s == 1 then
				return A(-14, 0, 0), A(-10, 0, 0)
			end
			return A(16, 0, 0), A(-6, 0, 0)
		end,
	},
	point = { -- right arm points up and out, left fist pumps
		arm = function(s)
			if s == 1 then
				return A(140, 0, 25), A(5, 0, 0)
			end
			return A(30, 0, -15), A(100, 0, 0)
		end,
		leg = function(s)
			if s == 1 then
				return A(12, 0, 0), CFrame.new()
			end
			return A(-12, 0, 0), A(-14, 0, 0)
		end,
	},
	tada = {
		arm = function(s)
			return A(15, 0, s * 135), A(25, 0, 0)
		end,
	},
	cheer = {
		arm = function(s)
			return A(170, 0, s * 25), A(20, 0, 0)
		end,
		leg = function(s)
			return A(0, 0, s * 10), CFrame.new()
		end,
	},
}

local function part(parent, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

function _G.avatar(cf: CFrame, poseName: string, lookAt: Vector3?)
	local d = Instance.new("HumanoidDescription")
	d.HairAccessory = "63690008"
	d.Shirt = 144076358
	d.Pants = 144076760
	d.Torso, d.RightArm, d.LeftArm, d.LeftLeg, d.RightLeg = 27112025, 27112039, 27112052, 27112056, 27112068
	d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor =
		WHITE, WHITE, WHITE, WHITE, WHITE, WHITE
	local m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	m.Name = "Bacon"
	m.Parent = stage()
	m.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local an = m.Humanoid:FindFirstChildOfClass("Animator")
	if an then
		an:Destroy()
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	local pose = POSES[poseName]
	-- cf = where the feet stand; the root sits at hip height
	local hip = m.HumanoidRootPart.Size.Y / 2 + m.LeftUpperLeg.Size.Y + m.LeftLowerLeg.Size.Y + m.LeftFoot.Size.Y
	m.HumanoidRootPart.CFrame = cf * CFrame.new(0, hip - 0.3, 0)
	fk(m, "HumanoidRootPart", "LowerTorso", "RootRigAttachment", CFrame.new())
	fk(m, "LowerTorso", "UpperTorso", "WaistRigAttachment", poseName == "pull" and A(-8, 0, 0) or CFrame.new())
	for _, side in { "Right", "Left" } do
		local s = side == "Right" and 1 or -1
		local h, k = CFrame.new(), CFrame.new()
		if pose.leg then
			h, k = pose.leg(s)
		end
		fk(m, "LowerTorso", side .. "UpperLeg", side .. "HipRigAttachment", h)
		fk(m, side .. "UpperLeg", side .. "LowerLeg", side .. "KneeRigAttachment", k)
		fk(m, side .. "LowerLeg", side .. "Foot", side .. "AnkleRigAttachment", CFrame.new())
		local sh, el = pose.arm(s)
		fk(m, "UpperTorso", side .. "UpperArm", side .. "ShoulderRigAttachment", sh)
		fk(m, side .. "UpperArm", side .. "LowerArm", side .. "ElbowRigAttachment", el)
		fk(m, side .. "LowerArm", side .. "Hand", side .. "WristRigAttachment", CFrame.new())
	end
	local neck = CFrame.new()
	if lookAt then
		local to = m.UpperTorso.CFrame:PointToObjectSpace(lookAt)
		local yaw = math.clamp(math.deg(math.atan2(-to.X, -to.Z)), -60, 60)
		local pitch = math.clamp(math.deg(math.atan2(to.Y, math.sqrt(to.X ^ 2 + to.Z ^ 2))), -20, 25)
		neck = A(0, yaw, 0) * A(pitch, 0, 0)
	end
	fk(m, "UpperTorso", "Head", "NeckRigAttachment", neck)

	-- the classic head with the classic smile (new heads ignore HumanoidDescription.Face)
	local head = m.Head
	head.Transparency = 1
	for _, x in head:GetChildren() do
		if x:IsA("Decal") then
			x:Destroy()
		end
	end
	local ch = part(m, Vector3.new(2, 1, 1), head.CFrame, WHITE)
	ch.Name = "ClassicHead"
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Head
	sm.Scale = Vector3.new(1.2, 1.2, 1.2)
	sm.Parent = ch
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = ch
	for _, acc in m:GetChildren() do
		if acc:IsA("Accessory") then
			local h = acc.Handle
			local att = h:FindFirstChildWhichIsA("Attachment")
			h.Anchored = true
			h.CFrame = head.CFrame * head[att.Name].CFrame * att.CFrame:Inverse()
		end
	end
	-- feet on the ground: drop the posed model so its lowest foot touches cf's height
	local low = math.huge
	for _, f in { m.LeftFoot, m.RightFoot } do
		local h = f.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					low = math.min(low, (f.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
				end
			end
		end
	end
	local dy = cf.Position.Y - low
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame += Vector3.new(0, dy, 0)
		end
	end
	for _, x in m:GetDescendants() do
		if x:IsA("Attachment") or x:IsA("JointInstance") or x:IsA("Bone") or x:IsA("Constraint") or x:IsA("NoCollisionConstraint") or x:IsA("WrapTarget") or x:IsA("WrapLayer") or x:IsA("FaceControls") then
			x:Destroy()
		end
	end
	return m
end

function _G.squishy(id: string, size: number, cf: CFrame, glitter: boolean?)
	local m = SquishyModel.build(id, size, glitter)
	local sp = Squishies.ById[id]
	if sp and sp.rainbow then
		-- the game cycles this body through the rainbow every frame (in Edit too): swap in a copy
		-- it doesn't know about, held at hot pink
		local old = m.PrimaryPart
		local body = old:Clone()
		body.Color = Color3.fromRGB(255, 80, 180)
		body.Parent = m
		m.PrimaryPart = body
		old:Destroy()
	end
	m:PivotTo(cf)
	m.Parent = stage()
	return m
end

function _G.goo(pos: Vector3, scale: number?)
	local m = RS.Assets.goo_blob:Clone()
	m:ScaleTo(scale or 1)
	m:PivotTo(CFrame.new(pos))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide = true, false
		end
	end
	m.Parent = stage()
	return m
end

function _G.pad(pos: Vector3, scale: number?, color: Color3?)
	local src = workspace.JellyPads:FindFirstChildWhichIsA("Model")
	local m = src:Clone()
	m:ScaleTo((scale or 1) * m:GetScale())
	m:PivotTo(CFrame.new(pos))
	if color then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = color
			end
		end
	end
	m.Parent = stage()
	return m
end

-- mask mode: remember every property it changes, and put them all back after
local saved: { { any } } = {}
local function set(inst, prop, value)
	table.insert(saved, { inst, prop, inst[prop] })
	inst[prop] = value
end

function _G.mask(on: boolean)
	if not on then
		for i = #saved, 1, -1 do
			local s = saved[i]
			s[1][s[2]] = s[3]
		end
		table.clear(saved)
		return "mask off"
	end
	local st = stage()
	local function staged(x)
		if x:IsDescendantOf(st) then
			return true
		end
		for _, f in _G.featured or {} do
			if x:IsDescendantOf(f) then
				return true
			end
		end
		return false
	end
	for _, x in workspace:GetDescendants() do
		if staged(x) then
			if x:IsA("BasePart") then
				if x.Transparency < 0.95 then
					set(x, "Color", Color3.new(1, 1, 1))
					set(x, "Material", Enum.Material.SmoothPlastic) -- Neon glows past the edge
					set(x, "Reflectance", 0)
					set(x, "Transparency", 0)
				end
				if x:IsA("MeshPart") then
					set(x, "TextureID", "")
				end
			elseif x:IsA("SpecialMesh") then
				set(x, "TextureId", "")
				set(x, "VertexColor", Vector3.new(1, 1, 1))
			elseif x:IsA("Decal") then
				set(x, "Transparency", 1)
			elseif x:IsA("ParticleEmitter") or x:IsA("Trail") or x:IsA("Beam") then
				set(x, "Enabled", false)
			elseif x:IsA("SurfaceAppearance") then
				set(x, "Parent", nil)
			end
		elseif x:IsA("BasePart") then
			set(x, "LocalTransparencyModifier", 1)
			set(x, "Transparency", 1)
		elseif x:IsA("Decal") or x:IsA("Texture") then
			set(x, "Transparency", 1)
		elseif x:IsA("Attachment") then
			set(x, "Visible", false)
		elseif x:IsA("ParticleEmitter") or x:IsA("SurfaceGui") or x:IsA("BillboardGui") then
			set(x, "Enabled", false)
		end
	end
	for _, x in workspace:GetDescendants() do
		if x:IsA("Clothing") and staged(x) then
			set(x, "Parent", nil)
		end
	end
	for _, c in game.Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			set(c, "Parent", nil)
		end
	end
	set(workspace.Terrain, "WaterTransparency", 1)
	local L = game.Lighting
	set(L, "ClockTime", 0)
	set(L, "Brightness", 0)
	set(L, "Ambient", Color3.new(1, 1, 1)) -- staged parts lit flat white by ambient alone
	set(L, "OutdoorAmbient", Color3.new(1, 1, 1))
	set(L, "EnvironmentDiffuseScale", 0)
	set(L, "EnvironmentSpecularScale", 0)
	set(L, "ExposureCompensation", 0)
	local cl = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if cl then
		set(cl, "Enabled", false)
	end
	return "mask on"
end

-- a plot's slingshot with its bands drawn to `pouchAt` (the game's own bands are Beams placed at
-- runtime; in Edit their attachments sit at the base and draw as green dots, so they're swapped
-- out until _G.clear())
function _G.sling(i: number, pouchAt: Vector3)
	local plot = workspace.Plots["Plot" .. i]
	local fa = plot.FlingAnchor
	local base = fa.Position
	for _, x in { fa, plot.Pouch } do
		for _, c in x:GetChildren() do
			set(c, "Parent", nil)
		end
	end
	set(plot.Pouch, "Position", pouchAt)
	for _, sx in { -2.2, 2.2 } do
		local a = base + Vector3.new(sx, 7.6, 0)
		local p = part(stage(), Vector3.new((a - pouchAt).Magnitude, 0.3, 0.3), CFrame.lookAt((a + pouchAt) / 2, pouchAt) * CFrame.Angles(0, math.rad(90), 0), Color3.fromHex("#FF8FC4"), Enum.PartType.Cylinder)
		p.Name = "Band"
	end
end

-- hide a map piece for the shot (put back by _G.clear())
function _G.hide(inst: Instance)
	for _, x in inst:GetDescendants() do
		if x:IsA("BasePart") then
			set(x, "Transparency", 1)
		elseif x:IsA("Decal") or x:IsA("Texture") then
			set(x, "Transparency", 1)
		elseif x:IsA("Beam") or x:IsA("ParticleEmitter") then
			set(x, "Enabled", false)
		end
	end
	if inst:IsA("BasePart") then
		set(inst, "Transparency", 1)
	end
end

-- plot name signs ("Free plot") and other floating labels off for the shot
function _G.hideSigns()
	for _, x in workspace:GetDescendants() do
		if x:IsA("BillboardGui") and x.Enabled then
			set(x, "Enabled", false)
		end
	end
end

-- the map's attachments draw as green dots in Studio captures
function _G.hideGizmos()
	for _, x in workspace:GetDescendants() do
		if x:IsA("Attachment") and x.Visible then
			x.Visible = false
		end
	end
end

function _G.clear()
	_G.mask(false) -- puts back everything set() changed (mask mode and _G.sling)
	local st = workspace:FindFirstChild("MarketingStage")
	if st then
		st:Destroy()
	end
	_G.featured = nil
end

return "stage ready"
