--!strict
-- Panels (DESIGN 7.3): Upgrades (Goo | Slingshot | Gloves | Shelf), Shelf / Inventory, Odds
-- (4.6). Hub prompts and HUD buttons open the same panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Mod = require(ReplicatedStorage.Shared.Util.Modifier)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Net = require(ReplicatedStorage.Kit.Net)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)
local ShelfView = require(script.Parent.ShelfView)
local SquishyModel = require(script.Parent.SquishyModel)

local P, F = Theme.Palette, Theme.Fonts
local E, S, Z, M, G = Config.Economy, Config.Squishies, Config.Zones, Config.Map, Config.Game
local player = Players.LocalPlayer

local Panels = {}
local refreshOpen: (() -> ())? = nil
local refreshName: string? = nil

local function attr(name: string, default: number): number
	return (player:GetAttribute(name) :: number?) or default
end

-- a 3D thumbnail of a squishy
function Panels.thumb(parent: Instance, s: string, size: number?, glitter: boolean?, props: { [string]: any }?, mod: string?): ViewportFrame
	local vp = Candy.make("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(200, 190, 220), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1), Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do
		(vp :: any)[k] = v
	end
	local m = SquishyModel.build(s, size or 1, glitter, mod)
	m:PivotTo(CFrame.new())
	m.Parent = vp
	local cam = Instance.new("Camera")
	local boxCf, box = m:GetBoundingBox()
	local c = boxCf.Position
	local r = math.max(box.X, box.Y, box.Z)
	cam.FieldOfView = 30
	-- squishies face -Z: look at the face from the front, a little above and to the side
	cam.CFrame = CFrame.lookAt(c + Vector3.new(r * 0.5, r * 0.4, -r * 1.7), c)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

local function row(parent: Instance, order: number, h: number?): Frame
	local f = Candy.pill(parent, UDim2.new(1, 0, 0, h or 92), P.cream, { LayoutOrder = order })
	Candy.corner(f, 18)
	return f
end

------------------------------------------------------------------ Upgrades
local function upgradeRow(list: Instance, order: number, iconText: string, name: string, effect: string, cost: number?, status: string, onBuy: () -> ())
	local f = row(list, order)
	f.Name = "Row" .. order
	local ic = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(14, 14), Parent = f })
	Candy.icon(ic, iconText, { TextColor3 = P.ink })
	Candy.label(f, name, { Font = F.header, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 36), Position = UDim2.fromOffset(92, 10) })
	Candy.label(f, effect, { Font = F.small, TextColor3 = Color3.fromHex("#6E5C8F"), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(92, 50) })
	local kind = if status == "buy" then "success" elseif status == "owned" then "secondary" else "disabled"
	local text = if status == "buy" or status == "poor" then Format.abbrev(cost or 0) elseif status == "owned" then "Owned" else "Locked"
	local b = Candy.button(f, text, kind, UDim2.fromOffset(200, 66), function()
		if status == "buy" then
			onBuy()
		else
			Sound.play("ui_error")
		end
	end, { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0) })
	if status == "poor" then
		b.setKind("disabled")
	end
	if status == "buy" or status == "poor" then
		Candy.buttonIcon(b, "coin")
	end
end

local function tierStatus(owned: number, tier: number, cost: number): string
	if tier <= owned then
		return "owned"
	elseif tier == owned + 1 then
		return if attr("coins", 0) >= cost then "buy" else "poor"
	end
	return "locked"
end

function Panels.upgrades(tab: string?)
	local modal = Candy.modal("Upgrades", "UPGRADES")
	local content = Candy.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = modal.body })
	local current = tab or "Goo"
	local function draw()
		local old = content:FindFirstChildOfClass("ScrollingFrame")
		local keep = if old then old.CanvasPosition else Vector2.zero
		content:ClearAllChildren()
		local list = Candy.scroll(content)
		task.defer(function()
			list.CanvasPosition = keep
		end)
		Candy.make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		if current == "Goo" then
			local owned = attr("goo", 1)
			for t, g in E.Goo do
				upgradeRow(list, t, "upgrades", g.name, ("Throw distance ×%.2f"):format(g.mult), g.cost, if t == 1 then "owned" else tierStatus(owned, t, g.cost), function()
					Net.send("BuyUpgrade", "goo", t)
				end)
			end
		elseif current == "Slingshot" then
			local owned = attr("sling", 1)
			for t, g in E.Slingshots do
				upgradeRow(list, t, "sp", g.name, if t == 1 then "Your starter slingshot" else ("Throw distance ×%.2f · new look"):format(g.mult), g.cost, if t == 1 then "owned" else tierStatus(owned, t, g.cost), function()
					Net.send("BuyUpgrade", "sling", t)
				end)
			end
		elseif current == "Gloves" then
			local owned = attr("gloves", 1)
			for t, g in E.Gloves do
				upgradeRow(list, t, "sp", g.name, ("+%d Sling Power per throw"):format(g.sp), g.cost, if t == 1 then "owned" else tierStatus(owned, t, g.cost), function()
					Net.send("BuyUpgrade", "gloves", t)
				end)
			end
		else
			local k = attr("slotUpgrades", 0)
			local slots = E.slotCount(k)
			if k < E.MaxSlotUpgrades then
				local cost = E.slotCost(k)
				upgradeRow(list, 1, "shelf", "+2 Shelf Slots", ("%d → %d slots"):format(slots, slots + 2), cost, if attr("coins", 0) >= cost then "buy" else "poor", function()
					Net.send("BuyUpgrade", "slots", k + 1)
				end)
			else
				upgradeRow(list, 1, "shelf", "Shelf Slots", "All 40 slots unlocked", nil, "owned", function() end)
			end
			local lvl = attr("shelfLevel", 1)
			for t, l in E.ShelfLevels do
				if t > 1 then
					upgradeRow(list, t + 1, "shelf", "Shelf Level " .. t, ("Income ×%.2f · %s"):format(l.mult, l.visual), l.cost, tierStatus(lvl, t, l.cost), function()
						Net.send("BuyUpgrade", "shelf", t)
					end)
				end
			end
		end
	end
	local select = Candy.tabs(modal.body, { "Goo", "Slingshot", "Gloves", "Shelf" }, function(name)
		current = name
		draw()
	end)
	select(current)
	refreshOpen, refreshName = draw, "Upgrades"
end

------------------------------------------------------------------ Shelf
-- Shelf | Inventory (DESIGN 4.4-4.6, 22). Squishies are grouped by species + size + Shiny +
-- modifier. Shelf cards: Merge / Store / Sell. Inventory cards: Equip / Merge / Sell / Sell all.
function Panels.shelf(view: string?)
	local modal = Candy.modal("Shelf", "MY SQUISHIES")
	local showing = if view == "Inventory" then "Inventory" else "Shelf"
	local sortBy = "Income"
	local SORTS = { "Income", "Rarity", "Newest" }
	local top = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Parent = modal.body })
	local info = Candy.label(modal.body, "", { Font = F.small, TextColor3 = Color3.fromHex("#6E5C8F"), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 28), Position = UDim2.fromOffset(4, 66) })
	local content = Candy.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 1, -100), Parent = modal.body })
	local confirm: string? = nil
	local lastSig = ""
	local draw: () -> ()

	local shelfTab = Candy.button(top, "Shelf", "secondary", UDim2.fromOffset(150, 56), function()
		showing, confirm = "Shelf", nil
		draw()
	end)
	local invTab = Candy.button(top, "Inventory", "secondary", UDim2.fromOffset(210, 56), function()
		showing, confirm = "Inventory", nil
		draw()
	end, { Position = UDim2.fromOffset(162, 0) })
	local sortBtn = Candy.button(top, "Sort: Income", "secondary", UDim2.fromOffset(210, 56), function()
		sortBy = SORTS[(table.find(SORTS, sortBy) or 1) % #SORTS + 1]
		draw()
	end, { Position = UDim2.fromOffset(384, 0) })
	Candy.button(top, "Equip Best", "success", UDim2.fromOffset(210, 56), function()
		Net.send("EquipBest")
		Sound.play("buy")
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0) })

	type Group = { s: string, size: number, glitter: boolean, mod: string?, uids: { string }, newest: number }
	local rarityIndex = {}
	for i, r in Z.Rarities do
		rarityIndex[r] = i
	end
	local function income(g: Group): number
		return S.ById[g.s].income * S.SizeMult[g.size] * Mod.incomeMult(Z, g.glitter, g.mod)
	end

	draw = function()
		local entries: { any } = if showing == "Shelf" then ShelfView.entries :: { any } else ShelfView.inv :: { any }
		-- squeezes resend the shelf every few seconds: rebuild only when what's shown changed
		local parts = { showing, sortBy, tostring(confirm), tostring(player:GetAttribute("autoMerge")), tostring(attr("Slots", 8)), tostring(#ShelfView.inv) }
		for _, e in entries do
			table.insert(parts, e.uid)
		end
		local sig = table.concat(parts, ",")
		if sig == lastSig and #content:GetChildren() > 0 then
			return
		end
		lastSig = sig
		content:ClearAllChildren()
		shelfTab.setKind(if showing == "Shelf" then "primary" else "secondary")
		invTab.setKind(if showing == "Inventory" then "primary" else "secondary")
		invTab.setText(("Inventory (%d)"):format(#ShelfView.inv))
		sortBtn.setText("Sort: " .. sortBy)
		info.Text = ("Shelf %d / %d slots  ·  Inventory %d / %d  ·  only shelf squishies earn coins"):format(#ShelfView.entries, attr("Slots", 8), #ShelfView.inv, G.InventoryCap)
		if #entries == 0 then
			local msg = if showing == "Shelf"
				then "Your shelf is empty.\nHold THROW at your slingshot to catch your first squishy!"
				else "Your inventory is empty.\nWhen your shelf is full, new squishies land here."
			Candy.label(content, msg, { Font = F.header, TextColor3 = Color3.fromHex("#6E5C8F"), Size = UDim2.new(1, 0, 0, 120) })
			return
		end
		local groups: { [string]: Group } = {}
		local order: { Group } = {}
		for i, e in entries do
			local key = ("%s|%d|%s|%s"):format(e.s, e.size, tostring(e.glitter), e.mod or "")
			local g: Group? = groups[key]
			if not g then
				local made: Group = { s = e.s, size = e.size, glitter = e.glitter == true, mod = e.mod, uids = {}, newest = 0 }
				groups[key] = made
				table.insert(order, made)
				g = made
			end
			local grp = g :: Group
			table.insert(grp.uids, e.uid)
			grp.newest = math.max(grp.newest, i)
		end
		table.sort(order, function(a, b)
			if sortBy == "Rarity" then
				local ra, rb = rarityIndex[S.ById[a.s].rarity], rarityIndex[S.ById[b.s].rarity]
				if ra ~= rb then
					return ra > rb
				end
			elseif sortBy == "Newest" then
				return a.newest > b.newest
			end
			return income(a) > income(b)
		end)
		local inInv = showing == "Inventory"
		local list = Candy.scroll(content)
		Candy.make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -12, 0, 300), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		local autoOn = player:GetAttribute("autoMerge") ~= false
		for n, g in order do
			local sp = S.ById[g.s]
			local card = Candy.pill(list, UDim2.fromOffset(100, 100), P.white, { LayoutOrder = n })
			Candy.corner(card, 18)
			local band = Candy.make("Frame", { BackgroundColor3 = Color3.fromHex(Z.RarityColors[sp.rarity]), Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0, Parent = card })
			Candy.corner(band, 4)
			local th = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 8), Parent = card })
			Panels.thumb(th, g.s, g.size, g.glitter, nil, g.mod)
			Candy.label(card, Mod.title(Z, S, g.s, g.size, g.glitter, g.mod), { Font = F.header, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 104) })
			local count = #g.uids
			local need = if g.size >= 3 then "" elseif count >= 3 then " — ready to merge!" else (" — %d more to merge!"):format(3 - count)
			Candy.label(card, ("×%d%s"):format(count, need), { Font = F.small, TextColor3 = Color3.fromHex("#6E5C8F"), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 130) })
			Candy.label(card, Format.abbrev(income(g)) .. "/s each" .. (if inInv then " on the shelf" else ""), { Font = F.body, TextColor3 = Color3.fromHex("#4DB52E"), Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 152) })
			local uid = g.uids[#g.uids]
			local function row(y: number): Frame
				local r = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, y), Parent = card })
				Candy.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = r })
				return r
			end
			local top2, bottom = row(-114), row(-58)
			local half = UDim2.new(0.5, -4, 1, 0)
			local canMerge = count >= 3 and g.size < 3 and (inInv or not autoOn)
			if inInv then
				Candy.button(top2, "Equip", "primary", if canMerge then half else UDim2.new(1, 0, 1, 0), function()
					Net.send("EquipSquishy", uid)
				end)
			else
				Candy.button(top2, "Store", "primary", if canMerge then half else UDim2.new(1, 0, 1, 0), function()
					Net.send("StoreSquishy", uid)
				end)
			end
			if canMerge then
				Candy.button(top2, "Merge", "success", half, function()
					Net.send("MergeRequest", g.s, g.size, g.glitter, g.mod or "", inInv)
				end)
			end
			-- selling: a second tap confirms anything rare, big or modified, and every "Sell all"
			local risky = g.size >= 2 or g.mod ~= nil or g.glitter or (table.find(Z.Rarities, sp.rarity) or 1) >= 4
			local function sellBtn(key: string, text: string, all: boolean, size: UDim2)
				local armed = confirm == key
				Candy.button(bottom, if armed then "Sure?" else text, if armed then "primary" else "secondary", size, function()
					if (risky or all) and confirm ~= key then
						confirm = key
						draw()
						return
					end
					confirm = nil
					Net.send("SellSquishy", uid, all)
				end)
			end
			if inInv and count > 1 then
				sellBtn("1" .. uid, "Sell", false, half)
				sellBtn("all" .. uid, ("Sell ×%d"):format(count), true, half)
			else
				sellBtn("1" .. uid, "Sell", false, UDim2.new(1, 0, 1, 0))
			end
		end
	end
	draw()
	refreshOpen, refreshName = draw, "Shelf"
end

------------------------------------------------------------------ Odds
function Panels.odds(zone: number?)
	local modal = Candy.modal("Odds", "ODDS")
	Panels.oddsInto(modal.body, zone)
	refreshOpen = nil
end

-- the odds table + notes in a scroll inside `parent` (the Odds panel and the Dex's Odds tab)
function Panels.oddsInto(parent: Instance, zone: number?)
	local list = Candy.scroll(parent)
	Candy.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local head = row(list, 0, 56)
	head.BackgroundColor3 = P.grape
	local cols = { "Zone", table.unpack(Z.Rarities) }
	for c, name in cols do
		local l = Candy.label(head, if c == 1 then name else name:sub(1, 4) .. (if #name > 4 then "." else ""), { Font = F.header, TextColor3 = P.white, Size = UDim2.new(if c == 1 then 0.28 else 0.12, 0, 1, -12), Position = UDim2.new(if c == 1 then 0 else 0.28 + (c - 2) * 0.12, 8, 0, 6) })
		Candy.textStroke(l, 1.5)
	end
	for i, z in Z.List do
		local r = row(list, i, 52)
		if i == zone then
			Candy.stroke(r, 4, P.pink)
		end
		Candy.label(r, z.name, { Font = F.header, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.28, -8, 1, -12), Position = UDim2.new(0, 12, 0, 6) })
		local w = Rarity.weights(Z, i, 0, false, M.BounceLuckPerBounce)
		for c, rname in Z.Rarities do
			local v = w[rname]
			Candy.label(r, if v > 0 then string.format("%g%%", math.floor(v * 10 + 0.5) / 10) else "—", { Font = F.body, TextColor3 = if v > 0 then Color3.fromHex(Z.RarityColors[rname]):Lerp(P.ink, 0.35) else Color3.fromHex("#B0A8C4"), Size = UDim2.new(0.12, 0, 1, -16), Position = UDim2.new(0.28 + (c - 1) * 0.12, 0, 0, 8) })
		end
	end
	local notes = {
		("Each Jelly Pad bounce multiplies Rare and better by ×%.2f: 1 bounce ×1.25 · 2 bounces ×%.2f · 3 bounces ×%.2f (then the odds are rescaled to 100%%)."):format(M.BounceLuckPerBounce, M.BounceLuckPerBounce ^ 2, M.BounceLuckPerBounce ^ 3),
		("Goo Rain (free, every 12 min): Rare and better ×%d, stacks with bounces."):format(Z.GooRainLuck),
		("Shiny: %g%% of every catch, ×%d income."):format(Z.GlitterChance * 100, Z.GlitterMult),
		("Modifiers: Big %g%% (×%g income) · Giant %g%% (×%g) · Galactic %g%% (×%g). Each bounce adds +%d%% to these chances."):format(
			Z.ModifierById.big.chance * 100, Z.ModifierById.big.mult, Z.ModifierById.giant.chance * 100, Z.ModifierById.giant.mult,
			Z.ModifierById.galactic.chance * 100, Z.ModifierById.galactic.mult, Z.ModifierBounceLuck * 100),
		"No Robux purchase changes any odds.",
	}
	for k, t in notes do
		local r = row(list, 10 + k, 64)
		Candy.label(r, t, { Font = F.small, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6) })
	end
end

------------------------------------------------------------------ wiring
function Panels.start()
	while not Hud.ready do
		task.wait()
	end
	Hud.panels.Upgrades = Panels.upgrades
	Hud.panels.Shelf = Panels.shelf
	Hud.panels.Odds = function(z: string?)
		Panels.odds(tonumber(z))
	end
	Hud.menuButton("Upgrades", "upgrades", 3, function()
		Panels.upgrades()
	end)
	Hud.menuButton("Shelf", "shelf", 4, function()
		Panels.shelf()
	end)

	-- hub prompts open panels on this client
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("Panel")
		local open = if type(panel) == "string" then Hud.panels[panel] else nil
		if open then
			open(prompt:GetAttribute("Tab") :: string?)
		end
	end)

	Net.listen("ToInventory", function(sid: string, g: boolean, m: string, pay: number)
		local name = Mod.title(Z, S, sid, 1, g, if m ~= "" then m else nil)
		if pay > 0 then
			Candy.toast(("Inventory full! Sold %s for %s"):format(name, Format.abbrev(pay)), P.pink)
		else
			Candy.toast(("Shelf full: %s went to your Inventory"):format(name), Color3.fromHex("#9B5CFF"))
		end
	end)
	Net.listen("Sold", function(pay: number)
		if pay > 0 then
			Sound.play("buy")
			Candy.toast("+" .. Format.abbrev(pay) .. " coins", Color3.fromHex("#4DB52E"))
		end
	end)
	Net.listen("BuyResult", function(_kind: string, _tier: number, ok: boolean)
		if ok then
			Sound.play("buy")
		else
			Sound.play("ui_error")
			Candy.toast("Not enough coins!", P.pink)
		end
	end)
	-- redraw the open panel when its data changes
	local function changed()
		if refreshOpen and refreshName and Candy.modalOpen() == refreshName then
			refreshOpen()
		end
	end
	ShelfView.onChanged = function()
		if Candy.modalOpen() == "Shelf" then
			changed()
		end
	end
	for _, a in { "goo", "gloves", "sling", "slotUpgrades", "shelfLevel", "autoMerge", "ShelfCount" } do
		player:GetAttributeChangedSignal(a):Connect(changed)
	end
	-- coins tick every second: only redraw Upgrades when what's affordable changes
	local lastSig = ""
	player:GetAttributeChangedSignal("coins"):Connect(function()
		if Candy.modalOpen() ~= "Upgrades" then
			return
		end
		local coins = attr("coins", 0)
		local nextGoo, nextGlove, nextLvl = E.Goo[attr("goo", 1) + 1], E.Gloves[attr("gloves", 1) + 1], E.ShelfLevels[attr("shelfLevel", 1) + 1]
		local nextSling = E.Slingshots[attr("sling", 1) + 1]
		local sig = table.concat({
			tostring(nextGoo ~= nil and coins >= nextGoo.cost),
			tostring(nextGlove ~= nil and coins >= nextGlove.cost),
			tostring(nextSling ~= nil and coins >= nextSling.cost),
			tostring(nextLvl ~= nil and coins >= nextLvl.cost),
			tostring(coins >= E.slotCost(attr("slotUpgrades", 0))),
		}, ",")
		if sig ~= lastSig then
			lastSig = sig
			changed()
		end
	end)
	Net.listen("ShelfUpdate", function()
		task.defer(changed)
	end)
end

return Panels
