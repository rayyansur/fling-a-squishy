--!strict
-- Game passes + products live in game/monetization.json (CI fills the ids); effects here.
return {
	CoinsPassMult = 2,
	AutoFlingInterval = 1.5,
	AutoFlingCharge = 0.8,
	AutoSqueezeInterval = 10,
	PartyMult = 2,
	PartyMinutes = 5,
	PartyMaxMinutes = 30,
	CoinPacks = {
		coin_bag = { floor = 5000, minutes = 10 },
		coin_jar = { floor = 25000, minutes = 45 },
		coin_tub = { floor = 120000, minutes = 180 },
	},
}
