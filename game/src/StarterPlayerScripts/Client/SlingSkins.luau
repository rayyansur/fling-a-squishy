--!strict
-- Slingshot tiers (DESIGN 20): every plot shows its owner's slingshot. The map builds the tier-1
-- model in each plot; for higher tiers this hides it and clones ReplicatedStorage.Assets.
-- Slingshots[tier] onto the same pivot (same fork geometry, so the bands still meet the tips).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingSkins = {}

local function setHidden(model: Instance, hidden: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("BaseT") == nil then
				d:SetAttribute("BaseT", d.Transparency)
			end
			d.Transparency = if hidden then 1 else d:GetAttribute("BaseT") :: number
		end
	end
end

local function refresh(plot: Instance)
	local base = plot:FindFirstChild("Slingshot") :: Model?
	if not base then
		return
	end
	local tier = (plot:GetAttribute("Sling") :: number?) or 1
	local old = plot:FindFirstChild("SlingSkin")
	if old and old:GetAttribute("Tier") == tier then
		return
	end
	if old then
		old:Destroy()
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Slingshots")
	local template = folder and folder:FindFirstChild(tostring(tier)) :: Model?
	if tier <= 1 or not template then
		setHidden(base, false)
		return
	end
	local skin = template:Clone()
	skin.Name = "SlingSkin"
	skin:SetAttribute("Tier", tier)
	for _, d in skin:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	skin:PivotTo(base:GetPivot())
	skin.Parent = plot
	setHidden(base, true)
end

function SlingSkins.start()
	local plots = workspace:WaitForChild("Plots")
	local function hook(plot: Instance)
		refresh(plot)
		plot:GetAttributeChangedSignal("Sling"):Connect(function()
			refresh(plot)
		end)
	end
	for _, plot in plots:GetChildren() do
		hook(plot)
	end
	plots.ChildAdded:Connect(hook)
end

return SlingSkins
