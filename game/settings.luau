--!nocheck
-- World + lighting for this game. Set from DESIGN.md (art direction, max players).
return function(ctx)
	local B, game = ctx.B, ctx.game
	local lighting = game:GetService("Lighting")
	lighting.Technology = B.E.Technology.Future
	lighting.ClockTime = 14
	lighting.GlobalShadows = true

	game:GetService("Players").MaxPlayers = ctx.config.maxPlayers or 12
	game:GetService("Workspace").StreamingEnabled = false
end
