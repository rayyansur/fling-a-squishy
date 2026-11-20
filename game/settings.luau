--!nocheck
-- Lighting + world (DESIGN 9.3).
return function(ctx)
	local B, game = ctx.B, ctx.game
	local R = B.R
	local L = game:GetService("Lighting")
	L.Technology = B.E.Technology.ShadowMap
	L.ClockTime = 12.5
	L.Brightness = 3
	L.Ambient = B.hex("#B9A8E6")
	L.OutdoorAmbient = B.hex("#D9CFF5")
	L.ColorShift_Top = B.hex("#FFF0D6")
	L.EnvironmentDiffuseScale = 0.6
	L.EnvironmentSpecularScale = 0.3
	L.GlobalShadows = true

	local atmo = B.I.new("Atmosphere")
	atmo.Density = 0.22
	atmo.Offset = 0.05
	atmo.Color = B.hex("#FFE6F5")
	atmo.Decay = B.hex("#C9B8FF")
	atmo.Haze = 0.8
	atmo.Glare = 0
	atmo.Parent = L

	local cc = B.I.new("ColorCorrectionEffect")
	cc.Name = "CandyGrade"
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.TintColor = B.hex("#FFFBFE")
	cc.Parent = L

	local bloom = B.I.new("BloomEffect")
	bloom.Name = "CandyBloom"
	bloom.Intensity = 0.45
	bloom.Size = 20
	bloom.Threshold = 1.4
	bloom.Parent = L

	local sky = B.I.new("Sky")
	sky.CelestialBodiesShown = false
	sky.Parent = L

	game:GetService("Players").MaxPlayers = ctx.config.maxPlayers or 12
	game:GetService("Workspace").StreamingEnabled = false
	_ = R
end
