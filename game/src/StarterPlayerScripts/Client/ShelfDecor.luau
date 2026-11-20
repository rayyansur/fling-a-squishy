--!strict
-- Shelf level visuals (DESIGN 4.6): every plot's LevelDecor pieces show once the plot's
-- ShelfLevel reaches their Level (lights, lollipop pillars, spinning star, rainbow arch with
-- sparkles). Free plots show the plain shelf.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ShelfDecor = {}
local player = Players.LocalPlayer

local function setShown(model: Instance, shown: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("BaseT") == nil then
				d:SetAttribute("BaseT", d.Transparency)
			end
			d.Transparency = if shown then d:GetAttribute("BaseT") :: number else 1
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = shown and player:GetAttribute("SetLow") ~= true
		end
	end
end

local function sparkles(arch: Instance)
	local host = arch:FindFirstChildWhichIsA("BasePart", true)
	if not host or host:FindFirstChild("Sparkle") then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Rate = 6
	pe.Lifetime = NumberRange.new(1, 1.6)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.LightEmission = 0.8
	pe.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("#FFD23F"))
	pe.Enabled = false
	pe.Parent = host
end

function ShelfDecor.refresh(plot: Instance)
	local decor = plot:FindFirstChild("LevelDecor")
	if not decor then
		return
	end
	local level = (plot:GetAttribute("ShelfLevel") :: number?) or 1
	for _, m in decor:GetChildren() do
		if m.Name == "Arch" then
			sparkles(m)
		end
		setShown(m, level >= ((m:GetAttribute("Level") :: number?) or 99))
	end
end

function ShelfDecor.start()
	local plots = workspace:WaitForChild("Plots")
	local toppers: { { part: BasePart, base: CFrame, pivot: Vector3 } } = {}
	for _, plot in plots:GetChildren() do
		ShelfDecor.refresh(plot)
		plot:GetAttributeChangedSignal("ShelfLevel"):Connect(function()
			ShelfDecor.refresh(plot)
		end)
		local decorFolder = plot:FindFirstChild("LevelDecor")
		local topper = decorFolder and decorFolder:FindFirstChild("StarTopper")
		if topper then
			-- the star + sparkles spin around the star's own vertical axis
			local star = topper:FindFirstChild("Star", true) :: BasePart?
			for _, d in topper:GetDescendants() do
				if d:IsA("BasePart") and star and d.Name ~= "Stick" and d.Name ~= "Pin" then
					table.insert(toppers, { part = d, base = d.CFrame, pivot = star.Position })
				end
			end
		end
	end
	player:GetAttributeChangedSignal("SetLow"):Connect(function()
		for _, plot in plots:GetChildren() do
			ShelfDecor.refresh(plot)
		end
	end)
	local a = 0
	RunService.Heartbeat:Connect(function(dt: number)
		a = (a + dt * 1.5) % (2 * math.pi)
		local cam = workspace.CurrentCamera
		local cp = if cam then cam.CFrame.Position else Vector3.zero
		for _, t in toppers do
			if t.part.Transparency < 1 and (t.pivot - cp).Magnitude < 250 then
				local rot = CFrame.new(t.pivot) * CFrame.Angles(0, a, 0) * CFrame.new(-t.pivot)
				t.part.CFrame = rot * t.base
			end
		end
	end)
end

return ShelfDecor
