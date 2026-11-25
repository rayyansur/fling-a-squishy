--!strict
-- Core loop timings (DESIGN 3, 13).
return {
	MaxPlayers = 12,
	FlingCooldown = 0.8, -- reload after a throw (a new squishy loads into the pouch)
	MinHold = 0.2, -- a shorter press throws nothing ("Hold to charge!"), so tapping can't spam
	MaxHopping = 6,
	ChargeCycle = 1.6, -- seconds for 0 -> 1 -> 0 (triangle wave): 0.8 s to the top
	SweetSpot = 0.85, -- charge >= this is PERFECT
	PerfectStreakMax = 5, -- PERFECTs in a row, shown as "PERFECT x3!"
	PerfectStreakDist = 0.05, -- +5% distance per streak step after the first
	AimClampDeg = 30,
	SteerDegPerSec = 55, -- A/D, arrows or the thumbstick while charging
	TouchDegPerPixel = 0.25, -- dragging the THROW finger sideways
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
	IncomeTick = 1,
}
