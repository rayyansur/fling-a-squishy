--!strict
-- Client entry. Opens the kit store button, then starts client modules placed under this script.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("StoreUI")).start()

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local mod = require(child) :: any
		if type(mod) == "table" and type(mod.start) == "function" then
			task.spawn(mod.start)
		end
	end
end
