--!strict
-- Server entry. Boots the kit (saves, purchases), then every ModuleScript under this script that
-- exposes start(); keep logic in modules so the cloud crash test can boot them the same way.
-- Started modules get a "Started" attribute so the crash test doesn't start them twice.
local Kit = game:GetService("ServerScriptService"):WaitForChild("Kit")
require(Kit:WaitForChild("Data")).start()
require(Kit:WaitForChild("Shop")).start()

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local mod = require(child) :: any
		if type(mod) == "table" and type(mod.start) == "function" then
			child:SetAttribute("Started", true)
			task.spawn(mod.start)
		end
	end
end
