--!strict
-- Types shared by the kit modules and the generated Catalog.

export type Item = {
	name: string,
	description: string?,
	price: number,
	icon: string?,
}

export type CatalogData = {
	passes: { [string]: Item },
	products: { [string]: Item },
	-- universe id -> kind -> key -> id (filled by CI: tools/roblox_cloud.py sync-products)
	ids: { [string]: { passes: { [string]: number }, products: { [string]: number } } },
}

export type Kind = "passes" | "products"

-- Config.Data (ReplicatedStorage.Shared.Config)
export type DataConfig = {
	store: string?, -- DataStore name; bump the suffix only for a deliberate wipe
	defaults: { [string]: any }?, -- new players start with a deep copy; missing keys are filled in on load
	mirror: { string }?, -- top-level keys copied to Player attributes (for client UI)
	leaderstats: { string }?, -- top-level number keys shown on the player list
	autosaveSeconds: number?,
}

-- Config.Theme, used by Kit.UI
export type Theme = {
	font: Enum.Font?,
	bg: Color3?,
	panel: Color3?,
	text: Color3?,
	subtext: Color3?,
	accent: Color3?,
	accentText: Color3?,
	good: Color3?,
	bad: Color3?,
	corner: number?,
}

-- Net.on spec: argument types (typeof names, "int" for whole numbers), rate limit per player
export type NetSpec = {
	args: { string }?,
	rate: number?, -- calls per second (sustained)
	burst: number?, -- calls allowed at once
	maxString: number?,
}

return {}
