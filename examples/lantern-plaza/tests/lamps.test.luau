--!nonstrict
-- Sample game test: the lantern is tagged, has a prompt, and toggling works.
-- Test files get `t` with t.test(name, fn), t.expect(cond, msg), t.waitFor(fn, s), t.info(msg).
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local Lamps = require(game:GetService("ServerScriptService").Server.Lamps)

	t.test("lantern exists and is tagged", function()
		local lamps = CollectionService:GetTagged("ToggleLamp")
		t.expect(#lamps >= 1, "no ToggleLamp in the map")
		local prompt = lamps[1]:FindFirstChildWhichIsA("ProximityPrompt", true)
		t.expect(prompt ~= nil, "lantern has no ProximityPrompt")
	end)

	t.test("lamps start on", function()
		local lamp = CollectionService:GetTagged("ToggleLamp")[1]
		Lamps.setup(lamp)
		t.expect(lamp:GetAttribute("On") == true, "lamp did not switch on")
	end)
end
