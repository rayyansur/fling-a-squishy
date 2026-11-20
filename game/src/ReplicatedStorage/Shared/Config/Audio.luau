--!strict
-- Sound ids (DESIGN 8). 0 = silent. Only Roblox-licensed audio: APMOfficial music and
-- ProSoundEffects SFX (each id load-checked in Studio). Slots at 0 had no licensed match yet.
return {
	MusicVolume = 0.35,
	SfxVolume = 0.6,
	Crossfade = 1.2,
	Music = {
		main_theme = 1836039989, -- APM "Bouncy Way" (71 s)
		goo_rain = 1836039897, -- APM "Be In The Running" (46 s)
		resquish_sting = 1847254868, -- APM "Mini Sting 21" (5 s)
	},
	Sfx = {
		sling_stretch = 0,
		sling_release = 0,
		perfect = 0,
		boing = 0,
		splat = 9114615835, -- PSE thick wet splat
		pop_out = 9113263647, -- PSE cartoon balloon pop
		hop = 0,
		squish = 9120222027, -- PSE toy squeak
		merge = 0,
		coin_burst = 9113704038, -- PSE candy machine coin drops
		buy = 0,
		rare_reveal = 9047214582, -- APM "Party In The Wild" tag
		legendary_fanfare = 0,
		goo_rain_jingle = 0,
		ui_click = 0,
		ui_error = 0,
		ambient = 0,
	},
}
