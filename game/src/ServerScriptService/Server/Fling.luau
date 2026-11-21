--!strict
-- FlingRequest (DESIGN 3, 4.1, 6.3): validate, compute the full path with bounces, roll the
-- squishy at the splat, broadcast the visuals, and deliver it to the shelf at arriveAt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local T = require(ReplicatedStorage.Shared.Util.Trajectory)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Net = require(ReplicatedStorage.Kit.Net)
local Data = require(ServerScriptService.Kit.Data)
local State = require(script.Parent.State)
local Plots = require(script.Parent.Plots)
local Shelf = require(script.Parent.Shelf)
local Tutorial = require(script.Parent.Tutorial)
local Analytics = require(script.Parent.Analytics)
local Progress = require(script.Parent.Progress)

local G, M, Z, S, E = Config.Game, Config.Map, Config.Zones, Config.Squishies, Config.Economy
local rules = T.rulesFrom(M)
local rng = Random.new()

local Fling = {}
-- Goo Rain hooks (the GooRain module sets this; false until it exists)
Fling.gooRain = function(): boolean
	return false
end

local RARITY_INDEX = {}
for i, r in Z.Rarities do
	RARITY_INDEX[r] = i
end

-- pick a species: rarity from the zone weights (+ luck), species uniform, Glitter 1%
function Fling.roll(zone: number, bounces: number, gooRain: boolean, r1: number, r2: number, r3: number): (string, boolean, string)
	local weights = Rarity.weights(Z, zone, bounces, gooRain, M.BounceLuckPerBounce)
	local rarity = Rarity.pick(weights, Z.Rarities, r1)
	local pool = S.ByRarity[rarity]
	local sp = pool[math.clamp(math.floor(r2 * #pool) + 1, 1, #pool)]
	return sp.id, r3 < Z.GlitterChance, rarity
end

-- plain table copy of a path for the remote
local function wire(path: T.Path): { any }
	local segs = table.create(#path.segments)
	for _, s in path.segments do
		table.insert(segs, { endPos = s.to, time = s.time, apex = s.apex, pad = s.pad or 0 })
	end
	return segs
end

local function atSlingshot(player: Player, i: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local fp = Plots.flingPoint(i)
	local d = Vector3.new(root.Position.X - fp.X, 0, root.Position.Z - fp.Z).Magnitude
	return d <= G.FlingReach + 2 -- a little slack for lag
end

-- extra jitter allowed between the client's hold time and the server's (seconds)
local ChargeSlack = 0.12

function Fling.request(player: Player, charge: number, yawDeg: number, auto: boolean?): boolean
	local data = Data.get(player)
	local i = Plots.indexOf(player)
	if not data or not i or not player:GetAttribute("Ready") then
		return false
	end
	local st = State.get(player)
	local now = os.clock()
	if now - st.lastFling < G.FlingCooldown - 0.05 or st.hopping >= G.MaxHopping then
		return false
	end
	if not atSlingshot(player, i) then
		return false
	end
	st.lastFling = now
	charge = math.clamp(charge, 0, 1)
	if not auto then
		-- the charge must match how long the player actually held (server clock)
		local began = st.chargeStart
		st.chargeStart = nil
		if not began or now - began > 30 then
			return false
		end
		charge = T.verifyCharge(charge, now - began, G.ChargeCycle, ChargeSlack)
	end
	yawDeg = math.clamp(yawDeg, -G.AimClampDeg, G.AimClampDeg)

	local start = Plots.flingPoint(i)
	local gooRain = Fling.gooRain()
	local rigFirst = Tutorial.rigFirst(player)
	local curve, perfect = T.chargeCurve(charge, G.SweetSpot, E.ChargeFloor)
	if auto then
		perfect = false -- Auto-Fling never counts as PERFECT
	end
	local path: T.Path
	if rigFirst then
		perfect = true
		local pad = T.lanePad(start, M.JellyPads, 2)
		path = T.rigged(start, M.JellyPads, pad :: number, rules)
	else
		local len = T.power(data.sp, E.Goo[data.goo].mult, data.reSquishes, gooRain, E) * curve
		path = T.compute(start, T.direction(yawDeg), len, M.JellyPads, rules)
	end

	local zone = T.zoneOf(path.distance, Z.List)
	local s, g, rarity = Fling.roll(zone, path.bounces, gooRain, rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
	if rigFirst then
		local pool = S.ByRarity.Uncommon
		s, g, rarity = pool[rng:NextInteger(1, #pool)].id, false, "Uncommon"
	elseif Tutorial.rigThird(player) and #data.shelf > 0 then
		local owned = data.shelf[rng:NextInteger(1, #data.shelf)]
		local known = S.ById[owned.s]
		s, rarity = owned.s, if known then known.rarity else rarity
		g = false
	end

	-- stats + Sling Power
	local spGain = E.Gloves[data.gloves].sp
	local flings = 0
	Data.update(player, function(d)
		d.sp += spGain
		d.stats.flings += 1
		flings = d.stats.flings
		if perfect then
			d.stats.perfects += 1
		end
		d.stats.bounces += path.bounces
		if path.bounces >= 3 then
			d.stats.tripleBounces += 1
		end
		d.stats.highestZone = math.max(d.stats.highestZone, zone)
	end)
	Tutorial.onFling(player, flings, path.bounces > 0)
	Progress.emit(player, "fling", 1)
	if perfect then
		Progress.emit(player, "perfect", 1)
	end
	if path.bounces >= 3 then
		Progress.emit(player, "triple", 1)
	end
	Progress.emit(player, "zone", zone)
	Analytics.custom(player, "CatchRarity", RARITY_INDEX[rarity])
	if rng:NextInteger(1, 10) == 1 then
		Analytics.custom(player, "Bounces", path.bounces)
	end

	-- timings on the shared clock
	local t0 = workspace:GetServerTimeNow()
	local flight = 0
	for _, seg in path.segments do
		flight += seg.time
	end
	local landAt = t0 + flight
	local shelfPos = Plots.shelfPoint(i)
	local hopDist = Vector3.new(path.final.X - shelfPos.X, 0, path.final.Z - shelfPos.Z).Magnitude
	local speed = G.HopSpeed * (if gooRain then 2 else 1)
	local popTime = 0.35
	local arriveAt = landAt + popTime + hopDist / speed + G.ArrivalPad

	st.hopping += 1
	player:SetAttribute("Hopping", st.hopping)
	local uid = ("%d-%d"):format(player.UserId, flings)
	Net.fireAll("FlingVisual", player.UserId, start, wire(path), data.goo, perfect, t0, path.bounces)
	Net.fireAll("SquishySpawned", player.UserId, uid, s, g, path.final, landAt, arriveAt, zone)

	-- big catches: everyone hears about it at the splat
	local ri = RARITY_INDEX[rarity]
	if ri >= 5 then
		task.delay(math.max(0, landAt - workspace:GetServerTimeNow()), function()
			local sp = S.ById[s]
			Net.fireAll("Announce", ("⭐ %s threw a %s %s!"):format(player.DisplayName, string.upper(rarity), sp.name), rarity)
		end)
	end

	local epoch = st.epoch
	task.delay(math.max(0, arriveAt - workspace:GetServerTimeNow()), function()
		st.hopping = math.max(0, st.hopping - 1)
		if player.Parent then
			player:SetAttribute("Hopping", st.hopping)
			if st.epoch ~= epoch then
				return -- flung before a Re-Squish: it went into the machine too
			end
			Shelf.arrive(player, s, g)
			Progress.emit(player, "catch", ri, g)
			if ri >= 3 then
				Progress.emit(player, "rare", 1)
			end
			if gooRain then
				Progress.emit(player, "rain", 1)
			end
		end
	end)
	return true
end

function Fling.start()
	Net.declare({ "FlingVisual", "SquishySpawned" })
	Net.on("ChargeBegin", { args = {}, rate = G.FlingRate, burst = G.FlingRate }, function(player)
		State.get(player).chargeStart = os.clock()
	end)
	Net.on("FlingRequest", { args = { "number", "number" }, rate = G.FlingRate, burst = G.FlingRate }, function(player, charge, yaw)
		Fling.request(player, charge, yaw)
	end)
	Players.PlayerAdded:Connect(function(p)
		p:SetAttribute("Hopping", 0)
	end)
end

return Fling
