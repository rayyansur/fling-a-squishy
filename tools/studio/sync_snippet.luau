-- Paste into Studio MCP execute_luau (Edit). Installs the latest PipelineSync from the
-- local build server and rebuilds the game in the open workbench place.
local url = "http://127.0.0.1:34872/studio"
local hs = game:GetService("HttpService")
hs.HttpEnabled = true
local src = hs:GetAsync(url .. "/PipelineSync.luau", true)
local ss = game:GetService("ServerStorage")
local old = ss:FindFirstChild("PipelineSync")
if old then
	old:Destroy()
end
local m = Instance.new("ModuleScript")
m.Name = "PipelineSync"
m.Source = src
m.Parent = ss
local result = require(m).sync(url)
-- the UI audit (tools/studio/ui_audit.luau) as a module the playtest client can run:
-- execute_luau (Client): return require(game.ReplicatedStorage.PipelineUIAudit)()
local ok, auditSrc = pcall(hs.GetAsync, hs, url .. "/ui_audit.luau", true)
if ok then
	local a = game.ReplicatedStorage:FindFirstChild("PipelineUIAudit")
	if a then
		a:Destroy()
	end
	a = Instance.new("ModuleScript")
	a.Name = "PipelineUIAudit"
	a.Source = "return function()\n" .. auditSrc .. "\nend"
	a.Parent = game.ReplicatedStorage
end
return result
