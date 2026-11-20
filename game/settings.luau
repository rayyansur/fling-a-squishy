--!nocheck
-- Lighting + world (DESIGN 9.3).
return function(ctx)
	local B, game = ctx.B, ctx.game
	local R = B.R
	local L = game:GetService("Lighting")
	L.Technology = B.E.Technology.ShadowMap
	L.ClockTime = 12.5
	L.Brightness = 2.2
	L.ExposureCompensation = -0.25
	L.Ambient = B.hex("#8C7CBF")
	L.OutdoorAmbient = B.hex("#A99BD6")
	L.ColorShift_Top = B.hex("#FFF0D6")
	L.EnvironmentDiffuseScale = 0.6
	L.EnvironmentSpecularScale = 0.3
	L.GlobalShadows = true

	local atmo = B.I.new("Atmosphere")
	atmo.Density = 0.12
	atmo.Offset = 0
	atmo.Color = B.hex("#FFE6F5")
	atmo.Decay = B.hex("#C9B8FF")
	atmo.Haze = 0.15
	atmo.Glare = 0
	atmo.Parent = L

	local cc = B.I.new("ColorCorrectionEffect")
	cc.Name = "CandyGrade"
	cc.Saturation = 0.25
	cc.Contrast = 0.12
	cc.TintColor = B.hex("#FFFFFF")
	cc.Parent = L

	local bloom = B.I.new("BloomEffect")
	bloom.Name = "CandyBloom"
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 2
	bloom.Parent = L

	local sky = B.I.new("Sky")
	sky.CelestialBodiesShown = false
	sky.Parent = L

	-- TextChatService chat (the HUD moves its window top-right; legacy chat can't be moved)
	game:GetService("TextChatService").ChatVersion = B.E.ChatVersion.TextChatService
	game:GetService("Players").MaxPlayers = ctx.config.maxPlayers or 12
	game:GetService("Workspace").StreamingEnabled = false
	_ = R
end
