--!strict
-- Fling paths (DESIGN 3, 4.1, 2.3). Pure: the server computes the real path, the client uses
-- firstSegment for the aim preview. Positions are Vector3s; distances are on the XZ plane.
local Trajectory = {}

export type Pad = { x: number, z: number, zone: number? }
export type Segment = { from: Vector3, to: Vector3, length: number, time: number, apex: number, pad: number? }
export type Path = { segments: { Segment }, final: Vector3, distance: number, bounces: number }
export type Rules = {
	minDistance: number,
	maxDistance: number,
	landXMin: number,
	landXMax: number,
	groundY: number,
	padY: number,
	padRadius: number,
	maxBounces: number,
	bounceDistanceFactor: number,
	bounceApexFactor: number,
}

function Trajectory.rulesFrom(Map: any): Rules
	return {
		minDistance = Map.MinDistance,
		maxDistance = Map.MaxDistance,
		landXMin = Map.LandXMin,
		landXMax = Map.LandXMax,
		groundY = Map.Valley.y,
		padY = Map.Valley.y + Map.PadHeight + 0.5,
		padRadius = Map.PadRadius,
		maxBounces = Map.MaxBounces,
		bounceDistanceFactor = Map.BounceDistanceFactor,
		bounceApexFactor = Map.BounceApexFactor,
	}
end

-- the charge meter: a triangle wave 0 -> 1 -> 0 over `cycle` seconds of holding
function Trajectory.chargeAt(held: number, cycle: number): number
	local phase = (math.max(0, held) % cycle) / cycle
	return if phase < 0.5 then phase * 2 else 2 - phase * 2
end

-- the server's view of a charge: the client's value is accepted only if the meter could have
-- shown it at some hold time within `slack` seconds of what the server measured (latency jitter);
-- otherwise the server's own estimate is used. Stops "always send 1.0" exploits.
function Trajectory.verifyCharge(claimed: number, held: number, cycle: number, slack: number): number
	local lo, hi = math.huge, -math.huge
	local steps = 12
	for k = 0, steps do
		local c = Trajectory.chargeAt(held - slack + 2 * slack * k / steps, cycle)
		lo, hi = math.min(lo, c), math.max(hi, c)
	end
	if claimed >= lo - 0.02 and claimed <= hi + 0.02 then
		return claimed
	end
	return Trajectory.chargeAt(held, cycle)
end

-- charge curve: floor + (1 - floor)c, or `perfectMult` (default 1) and PERFECT at the sweet spot
function Trajectory.chargeCurve(c: number, sweet: number, floor: number, perfectMult: number?): (number, boolean)
	c = math.clamp(c, 0, 1)
	if c >= sweet then
		return perfectMult or 1, true
	end
	return floor + (1 - floor) * c, false
end

-- extra distance for a PERFECT streak: the first PERFECT is x1, each one after adds `per`
function Trajectory.streakMult(streak: number, per: number): number
	return 1 + per * math.max(0, streak - 1)
end

-- first segment length (DESIGN 4.1) before the charge curve
function Trajectory.power(sp: number, gooMult: number, reSquishes: number, gooRain: boolean, E: any): number
	local reMult = 1 + E.ReSquish.distPer * reSquishes
	local rainMult = if gooRain then 1.25 else 1
	return (E.DistBase + E.DistPerRootSP * math.sqrt(math.max(1, sp))) * gooMult * reMult * rainMult
end

-- unit XZ direction for a yaw in degrees, 0 = +Z, positive = towards +X
function Trajectory.direction(yawDeg: number): Vector3
	local r = math.rad(yawDeg)
	return Vector3.new(math.sin(r), 0, math.cos(r))
end

function Trajectory.flightTime(length: number): number
	return 0.35 + length / 600
end

function Trajectory.firstApex(length: number): number
	return 8 + length * 0.15
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function padAt(p: Vector3, pads: { Pad }, radius: number, skip: number?): number?
	local best, bestD = nil, radius
	for i, pad in pads do
		if i ~= skip then
			local d = math.sqrt((p.X - pad.x) ^ 2 + (p.Z - pad.z) ^ 2)
			if d <= bestD then
				best, bestD = i, d
			end
		end
	end
	return best
end

-- Full path from `start` (the Fling Point) in direction `dir` with first segment `length1`.
-- Clamps: total XZ distance from start in [min, max], landing X in [landXMin, landXMax].
function Trajectory.compute(start: Vector3, dir: Vector3, length1: number, pads: { Pad }, rules: Rules): Path
	dir = flat(dir)
	dir = if dir.Magnitude > 1e-6 then dir.Unit else Vector3.new(0, 0, 1)
	local origin = flat(start)
	local segments: { Segment } = {}
	local from = start
	local length = math.max(length1, rules.minDistance)
	local apex = Trajectory.firstApex(length)
	local bounces = 0
	local lastPad: number? = nil
	local finalXZ = origin
	while true do
		local fromXZ = flat(from)
		local toXZ = fromXZ + dir * length
		-- clamp total distance
		local total = (toXZ - origin).Magnitude
		if total > rules.maxDistance then
			toXZ = origin + (toXZ - origin).Unit * rules.maxDistance
		end
		toXZ = Vector3.new(math.clamp(toXZ.X, rules.landXMin, rules.landXMax), 0, toXZ.Z)
		local segLen = (toXZ - fromXZ).Magnitude
		local pad = if bounces < rules.maxBounces and total <= rules.maxDistance then padAt(toXZ, pads, rules.padRadius, lastPad) else nil
		local y = if pad then rules.padY else rules.groundY
		local to = Vector3.new(toXZ.X, y, toXZ.Z)
		table.insert(segments, {
			from = from,
			to = to,
			length = segLen,
			time = Trajectory.flightTime(segLen),
			apex = apex,
			pad = pad,
		})
		finalXZ = toXZ
		if not pad or segLen < 1 then
			break
		end
		bounces += 1
		lastPad = pad
		from = to
		length = segLen * rules.bounceDistanceFactor
		apex *= rules.bounceApexFactor
	end
	local final = segments[#segments].to
	local distance = math.max(rules.minDistance, (finalXZ - origin).Magnitude)
	return { segments = segments, final = final, distance = distance, bounces = bounces }
end

-- Rigged tutorial path: segment 1 ends on pad `padIndex`, then exactly one bounce.
function Trajectory.rigged(start: Vector3, pads: { Pad }, padIndex: number, rules: Rules): Path
	local pad = pads[padIndex]
	local origin = flat(start)
	local target = Vector3.new(pad.x, 0, pad.z)
	local dir = (target - origin).Unit
	local len1 = (target - origin).Magnitude
	local seg1: Segment = {
		from = start,
		to = Vector3.new(pad.x, rules.padY, pad.z),
		length = len1,
		time = Trajectory.flightTime(len1),
		apex = Trajectory.firstApex(len1),
		pad = padIndex,
	}
	local len2 = len1 * rules.bounceDistanceFactor
	local endXZ = target + dir * len2
	endXZ = Vector3.new(math.clamp(endXZ.X, rules.landXMin, rules.landXMax), 0, endXZ.Z)
	local seg2: Segment = {
		from = seg1.to,
		to = Vector3.new(endXZ.X, rules.groundY, endXZ.Z),
		length = len2,
		time = Trajectory.flightTime(len2),
		apex = seg1.apex * rules.bounceApexFactor,
		pad = nil,
	}
	return { segments = { seg1, seg2 }, final = seg2.to, distance = (endXZ - origin).Magnitude, bounces = 1 }
end

-- Position along a segment at fraction a (0..1): straight in XZ, a parabola in Y that rises
-- `apex` studs above the straight line between the ends.
function Trajectory.at(seg: Segment, a: number): Vector3
	local p = seg.from:Lerp(seg.to, a)
	return p + Vector3.new(0, 4 * a * (1 - a) * seg.apex, 0)
end

-- zone index (1..#zones) for a distance
function Trajectory.zoneOf(distance: number, zones: { any }): number
	for i = #zones, 1, -1 do
		if distance >= zones[i].min then
			return i
		end
	end
	return 1
end

-- nearest pad of `zone` to a plot's lane (smallest |angle| from +Z), for the rigged first fling
function Trajectory.lanePad(start: Vector3, pads: { Pad }, zone: number): number?
	local best, bestA = nil, math.huge
	for i, pad in pads do
		if pad.zone == zone then
			local a = math.abs(math.atan2(pad.x - start.X, pad.z - start.Z))
			if a < bestA then
				best, bestA = i, a
			end
		end
	end
	return best
end

return Trajectory
