--!strict
-- The 24 squishies (DESIGN 4.8). income = coins/s at Normal size, before multipliers.
-- Optional look flags: mat (Roblox material for the body), glass (transparency), neon (accent
-- parts glow), rainbow (body colour cycles), fx (particle name on the model).
export type Species = {
	id: string,
	name: string,
	rarity: string,
	body: string,
	color: string,
	acc: string?,
	scale: number,
	income: number,
	mat: string?,
	transparency: number?,
	rainbow: boolean?,
	fx: string?,
}

local S = {}

S.Bodies = { "bun", "loaf", "bean", "blob" }
S.SizeNames = { "Normal", "Chonky", "Mega" }
S.SizeMult = { 1, 4, 16 }
S.SizeScale = { 1, 1.4, 1.9 }

S.List = {
	{ id = "bao_bun", name = "Bao Bun", rarity = "Common", body = "bun", color = "#FFF4E0", acc = "acc_steam", scale = 1.0, income = 1 },
	{ id = "mochi_blob", name = "Mochi Blob", rarity = "Common", body = "blob", color = "#FFD6E8", scale = 1.0, income = 1 },
	{ id = "jelly_bean", name = "Jelly Bean", rarity = "Common", body = "bean", color = "#FF6B6B", scale = 1.0, income = 1.5 },
	{ id = "marshmallow", name = "Marshmallow", rarity = "Common", body = "bun", color = "#FFFFFF", acc = "acc_toasted", scale = 0.9, income = 1.5 },

	{ id = "strawberry_puff", name = "Strawberry Puff", rarity = "Uncommon", body = "bun", color = "#FF4F6E", acc = "acc_strawberry", scale = 1.0, income = 4 },
	{ id = "peach_loaf", name = "Peach Loaf", rarity = "Uncommon", body = "loaf", color = "#FFB38A", acc = "acc_leaf", scale = 1.0, income = 4 },
	{ id = "cloud_puff", name = "Cloud Puff", rarity = "Uncommon", body = "blob", color = "#E6F7FF", acc = "acc_raindrop", scale = 1.0, income = 5 },
	{ id = "froggy_jelly", name = "Froggy Jelly", rarity = "Uncommon", body = "bean", color = "#7CF25A", acc = "acc_frog_eyes", scale = 1.0, income = 5 },

	{ id = "boba_bear", name = "Boba Bear", rarity = "Rare", body = "bun", color = "#E8C9A0", acc = "acc_boba", scale = 1.0, income = 14 },
	{ id = "avocado_pal", name = "Avocado Pal", rarity = "Rare", body = "bean", color = "#9BE36D", acc = "acc_avocado", scale = 1.0, income = 15 },
	{ id = "sushi_roll", name = "Sushi Roll", rarity = "Rare", body = "bun", color = "#FFFFFF", acc = "acc_sushi", scale = 1.0, income = 16 },
	{ id = "taco_pup", name = "Taco Pup", rarity = "Rare", body = "loaf", color = "#FFD23F", acc = "acc_taco", scale = 1.0, income = 18 },

	{ id = "donut_dragon", name = "Donut Dragon", rarity = "Epic", body = "loaf", color = "#FF4FA3", acc = "acc_donut_dragon", scale = 1.1, income = 50 },
	{ id = "cupcake_cat", name = "Cupcake Cat", rarity = "Epic", body = "loaf", color = "#FFE3F1", acc = "acc_cupcake", scale = 1.1, income = 55 },
	{ id = "octo_jelly", name = "Octo Jelly", rarity = "Epic", body = "blob", color = "#B78CFF", acc = "acc_tentacles", scale = 1.1, income = 60 },
	{ id = "unicorn_puff", name = "Unicorn Puff", rarity = "Epic", body = "bun", color = "#FFFFFF", acc = "acc_unicorn", scale = 1.1, income = 65 },

	{ id = "galaxy_cat", name = "Galaxy Cat", rarity = "Legendary", body = "loaf", color = "#2B1B4A", scale = 1.25, income = 180, fx = "stars" },
	{ id = "crown_cake", name = "Crown Cake", rarity = "Legendary", body = "bun", color = "#FFE3F1", acc = "acc_crown", scale = 1.25, income = 200 },
	{ id = "lava_mochi", name = "Lava Mochi", rarity = "Legendary", body = "blob", color = "#FF5A1F", acc = "acc_lava_cracks", scale = 1.25, income = 220, fx = "embers" },
	{ id = "crystal_bunny", name = "Crystal Bunny", rarity = "Legendary", body = "bean", color = "#BFF3FF", acc = "acc_bunny_ears", scale = 1.25, income = 240, mat = "Glass", transparency = 0.2 },

	{ id = "prism_blob", name = "Prism Blob", rarity = "Mythic", body = "blob", color = "#FF4FA3", acc = "acc_prism", scale = 1.4, income = 700, rainbow = true, fx = "prism" },
	{ id = "golden_bao", name = "Golden Bao", rarity = "Mythic", body = "bun", color = "#FFD23F", acc = "acc_gold_steam", scale = 1.4, income = 800 },
	{ id = "cosmic_whale", name = "Cosmic Whale", rarity = "Mythic", body = "loaf", color = "#3A2E8C", acc = "acc_star_spout", scale = 1.5, income = 900, fx = "nebula" },
	{ id = "mega_mochi", name = "Mega Mochi", rarity = "Mythic", body = "blob", color = "#FFD6E8", acc = "acc_party_hat", scale = 2.0, income = 1000 },
} :: { Species }

S.ById = {} :: { [string]: Species }
S.ByRarity = {} :: { [string]: { Species } }
for _, s in S.List do
	S.ById[s.id] = s
	S.ByRarity[s.rarity] = S.ByRarity[s.rarity] or {}
	table.insert(S.ByRarity[s.rarity], s)
end

return S
