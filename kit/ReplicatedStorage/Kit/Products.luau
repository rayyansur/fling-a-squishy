--!strict
-- Products: the game's passes and developer products (game/monetization.json) with the ids CI
-- created for the universe this server is running in. id 0 = not created there (yet), e.g. in
-- the Studio workbench; Kit.Shop grants those for free in Studio so every item can be tested.
local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local Products = {}

function Products.universe(): string
	return tostring(game.GameId)
end

function Products.get(kind: Types.Kind, key: string): Types.Item?
	return Catalog[kind][key]
end

function Products.id(kind: Types.Kind, key: string): number
	local ids = Catalog.ids[Products.universe()]
	return ids and ids[kind] and ids[kind][key] or 0
end

function Products.keyForId(kind: Types.Kind, id: number): string?
	local ids = Catalog.ids[Products.universe()]
	if not ids or not ids[kind] then
		return nil
	end
	for key, v in ids[kind] do
		if v == id then
			return key
		end
	end
	return nil
end

-- sorted by price, then key, so stores list items in a stable order
function Products.list(kind: Types.Kind): { { key: string, item: Types.Item } }
	local out = {}
	for key, item in Catalog[kind] do
		table.insert(out, { key = key, item = item })
	end
	table.sort(out, function(a, b)
		if a.item.price ~= b.item.price then
			return a.item.price < b.item.price
		end
		return a.key < b.key
	end)
	return out
end

-- Player attribute that says a pass is owned (set by Kit.Shop, read by client UI)
function Products.passAttribute(key: string): string
	return "Pass_" .. key
end

return Products
