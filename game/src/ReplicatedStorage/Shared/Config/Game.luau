--!strict
-- Core loop timings (DESIGN 3, 13).
return {
	MaxPlayers = 12,
	FlingCooldown = 0.5,
	MaxHopping = 6,
	ChargeCycle = 0.9, -- seconds for 0 -> 1 -> 0 (triangle wave)
	SweetSpot = 0.88, -- charge >= this is PERFECT
	AimClampDeg = 30,
	FlingReach = 8, -- HRP must be this close to the Fling Point
	HopSpeed = 70, -- studs/s horizontal (Goo Rain doubles it)
	ArrivalPad = 0.6, -- arriveAt = distance / speed + this
	AutosaveInterval = 90,
	OfflineRate = 0.5,
	OfflineCapHours = 6,
	SqueezeCooldown = 10,
	SqueezeSeconds = 5,
	SqueezeRate = 4, -- requests/s
	FlingRate = 4, -- requests/s
	ShelfFullAutoSeconds = 6,
	ReleaseSeconds = 30, -- release pays this many seconds of the squishy's income
	TutorialFlings = 10,
	TutorialCoinsHint = 600,
	IncomeTick = 1,
}
