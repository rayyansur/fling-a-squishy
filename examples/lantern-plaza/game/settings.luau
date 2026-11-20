--!nocheck
-- World + lighting settings for the sample game. Replace per game.
return function(ctx)
	local B, game = ctx.B, ctx.game
	local E = B.E
	local lighting = game:GetService("Lighting")
	lighting.Technology = E.Technology.Future
	lighting.ClockTime = 18.2
	lighting.Brightness = 1.8
	lighting.Ambient = B.hex("#40384a")
	lighting.OutdoorAmbient = B.hex("#8a7690")
	lighting.EnvironmentDiffuseScale = 0.6
	lighting.EnvironmentSpecularScale = 0.7
	lighting.GlobalShadows = true

	local atmo = B.I.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Color = B.hex("#d9a08a")
	atmo.Decay = B.hex("#5f4f74")
	atmo.Haze = 1.5
	atmo.Parent = lighting

	local bloom = B.I.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = lighting

	game:GetService("Players").MaxPlayers = 8
	game:GetService("StarterPlayer").CharacterWalkSpeed = 16
	game:GetService("Workspace").StreamingEnabled = false
end
