--!strict
-- StoreUI: the in-game store. Lists every pass and product from game/monetization.json with its
-- price, shows "Owned" for passes, odds for random items (StoreUI.setOdds) and a toast when a
-- purchase lands. Client-only.
--
--   StoreUI.start()                         -- adds the "Store" HUD button + purchase toasts
--   StoreUI.start({ hudButton = false, toast = false })  -- a game with its own store screen
--   StoreUI.setOdds("mystery_egg", Config.EggWeights, function(key) return Config.Pets[key].name end)
--   StoreUI.open()
local Players = game:GetService("Players")

local Kit = script.Parent
local Products = require(Kit.Products)
local Net = require(Kit.Net)
local Odds = require(Kit.Odds)
local UI = require(Kit.UI)

local StoreUI = {}

local ROBUX = utf8.char(0xE002) -- Robux glyph in Roblox fonts

local odds: { [string]: { weights: Odds.Weights, label: ((string) -> string)? } } = {}

function StoreUI.setOdds(key: string, weights: Odds.Weights, label: ((string) -> string)?)
	odds[key] = { weights = weights, label = label }
end

local function row(body: Instance, key: string, item: { name: string, description: string?, price: number }, isPass: boolean): Frame
	local t = UI.theme()
	local player = Players.LocalPlayer
	local card = UI.panel(body, UDim2.new(1, -8, 0, 0), nil, { AutomaticSize = Enum.AutomaticSize.Y })
	UI.text(card, item.name, { TextSize = 22, Size = UDim2.new(1, -150, 0, 28) })
	if item.description and item.description ~= "" then
		UI.text(card, item.description, {
			TextSize = 16,
			TextColor3 = t.subtext,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
	end
	local o = odds[key]
	if o then
		local lines = {}
		for _, e in Odds.percentages(o.weights) do
			table.insert(lines, ("%s %s"):format(if o.label then o.label(e.key) else e.key, Odds.format(e.percent)))
		end
		UI.text(card, "Odds: " .. table.concat(lines, " · "), {
			TextSize = 15,
			TextColor3 = t.accent,
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
	end
	local button = UI.button(card, ROBUX .. " " .. item.price, function()
		Net.send("Kit.Buy", key)
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(130, 48) })
	if isPass then
		local attr = Products.passAttribute(key)
		local function refresh()
			local has = player:GetAttribute(attr) == true
			button.Text = if has then "Owned" else ROBUX .. " " .. item.price
			button.Active = not has
			button.AutoButtonColor = false
			button.BackgroundColor3 = if has then t.panel else t.accent
			button.TextColor3 = if has then t.subtext else t.accentText
		end
		player:GetAttributeChangedSignal(attr):Connect(refresh)
		refresh()
	end
	return card
end

function StoreUI.open()
	local body = UI.modal("Store")
	local order = 0
	local function section(title: string)
		order += 1
		UI.text(body, title, { TextSize = 18, TextColor3 = UI.theme().subtext, LayoutOrder = order })
	end
	local passes, products = Products.list("passes"), Products.list("products")
	if #passes > 0 then
		section("Passes: yours forever")
		for _, e in passes do
			order += 1
			row(body, e.key, e.item, true).LayoutOrder = order
		end
	end
	if #products > 0 then
		section("Boosts")
		for _, e in products do
			order += 1
			row(body, e.key, e.item, false).LayoutOrder = order
		end
	end
	if #passes + #products == 0 then
		UI.text(body, "Nothing for sale yet.")
	end
end

type StartOptions = { hudButton: boolean?, toast: boolean? }

function StoreUI.start(options: StartOptions?)
	local opts: StartOptions = options or { hudButton = true, toast = true }
	if opts.hudButton ~= false and #Products.list("passes") + #Products.list("products") > 0 then
		UI.hudButton("Store", StoreUI.open)
	end
	if opts.toast == false then
		return
	end
	Net.listen("Kit.Purchased", function(kind: string, key: string)
		local item = Products.get(if kind == "passes" then "passes" else "products", key)
		UI.toast(("Thanks! %s is yours."):format(if item then item.name else key), "good")
	end)
end

return StoreUI
