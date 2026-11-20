--!nonstrict
-- Baseline world checks for every game; add feature suites next to this file.
return function(t)
	t.test("players have somewhere to spawn", function()
		t.expect(workspace:FindFirstChildWhichIsA("SpawnLocation", true) ~= nil, "no SpawnLocation in Workspace")
	end)
	t.test("nothing important sits below the kill floor", function()
		local low = 0
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.Position.Y < workspace.FallenPartsDestroyHeight + 10 then
				low += 1
			end
		end
		t.expect(low == 0, low .. " parts are below FallenPartsDestroyHeight")
	end)
end
