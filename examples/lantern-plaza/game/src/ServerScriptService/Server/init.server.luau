--!strict
-- Server entry. Every ModuleScript under this script exposes start(); keep logic in modules
-- so the cloud crash test can boot them the same way.
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local mod = require(child) :: any
		if type(mod) == "table" and type(mod.start) == "function" then
			task.spawn(mod.start)
		end
	end
end
