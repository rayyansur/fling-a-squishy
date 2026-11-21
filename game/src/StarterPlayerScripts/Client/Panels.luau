--!strict
-- Panels (DESIGN 7.3): Upgrades (Goo | Gloves | Shelf), Shelf, Odds, plus the Shelf Full modal
-- (4.6). Hub prompts and HUD buttons open the same panels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Net = require(ReplicatedStorage.Kit.Net)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)
local ShelfView = require(script.Parent.ShelfView)
local SquishyModel = require(script.Parent.SquishyModel)

local P, F = Theme.Palette, Theme.Fonts
local E, S, Z, M = Config.Economy, Config.Squishies, Config.Zones, Config.Map
local player = Players.LocalPlayer

local Panels = {}
local refreshOpen: (() -> ())? = nil
local refreshName: string? = nil

local function attr(name: string, default: number): number
	return (player:GetAttribute(name) :: number?) or default
end

-- a 3D thumbnail of a squishy
function Panels.thumb(parent: Instance, s: string, size: number?, glitter: boolean?, props: { [string]: any }?): ViewportFrame
	local vp = Candy.make("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(200, 190, 220), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1), Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do
		(vp :: any)[k] = v
	end
	local m = SquishyModel.build(s, size or 1, glitter)
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
	local select = Candy.tabs(modal.body, { "Goo", "Gloves", "Shelf" }, function(name)
		current = name
		draw()
	end)
	select(current)
	refreshOpen, refreshName = draw, "Upgrades"
end

------------------------------------------------------------------ Shelf
function Panels.shelf()
	local modal = Candy.modal("Shelf", "MY SHELF")
	local sortBy = "Income"
	local content = Candy.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = modal.body })
	local header = Candy.label(modal.body, "", { Font = F.header, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 300, 0, 50), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4) })
	local confirmUid: string? = nil
	local lastSig = ""
	local function draw()
		-- squeezes resend the shelf every few seconds: rebuild only when what's shown changed
		local parts = { sortBy, tostring(confirmUid), tostring(player:GetAttribute("autoMerge")), tostring(attr("Slots", 8)) }
		for _, e in ShelfView.entries do
			table.insert(parts, e.uid)
		end
		local sig = table.concat(parts, ",")
		if sig == lastSig and #content:GetChildren() > 0 then
			return
		end
		lastSig = sig
		content:ClearAllChildren()
		header.Text = ("%d / %d slots"):format(attr("ShelfCount", 0), attr("Slots", 8))
		local entries = ShelfView.entries
		if #entries == 0 then
			Candy.label(content, "Your shelf is empty.\nHold THROW at your slingshot to catch your first squishy!", { Font = F.header, TextColor3 = Color3.fromHex("#6E5C8F"), Size = UDim2.new(1, 0, 0, 120) })
			return
		end
		-- group by species + size + glitter
		type Group = { s: string, size: number, glitter: boolean, uids: { string }, newest: number }
		local groups: { [string]: Group } = {}
		local order: { Group } = {}
		for i, e in entries do
			local key = ("%s|%d|%s"):format(e.s, e.size, tostring(e.glitter))
			local g: Group? = groups[key]
			if not g then
				local made: Group = { s = e.s, size = e.size, glitter = e.glitter == true, uids = {}, newest = 0 }
				groups[key] = made
				table.insert(order, made)
				g = made
			end
			local grp = g :: Group
			table.insert(grp.uids, e.uid)
			grp.newest = math.max(grp.newest, i)
		end
		local rarityIndex = {}
		for i, r in Z.Rarities do
			rarityIndex[r] = i
		end
		local function income(g: Group): number
			return S.ById[g.s].income * S.SizeMult[g.size] * (if g.glitter then Z.GlitterMult else 1)
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
		local list = Candy.scroll(content)
		Candy.make("UIGridLayout", { CellSize = UDim2.new(1 / 3, -12, 0, 250), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		local autoOn = player:GetAttribute("autoMerge") ~= false
		for n, g in order do
			local sp = S.ById[g.s]
			local card = Candy.pill(list, UDim2.fromOffset(100, 100), P.white, { LayoutOrder = n })
			Candy.corner(card, 18)
			local band = Candy.make("Frame", { BackgroundColor3 = Color3.fromHex(Z.RarityColors[sp.rarity]), Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0, Parent = card })
			Candy.corner(band, 4)
			local th = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 8), Parent = card })
			Panels.thumb(th, g.s, g.size, g.glitter)
			local name = (if g.size > 1 then S.SizeNames[g.size] .. " " else "") .. sp.name .. (if g.glitter then " ✨" else "")
			Candy.label(card, name, { Font = F.header, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 104) })
			local count = #g.uids
			local need = if g.size >= 3 then "" elseif count >= 3 then " — ready to merge!" else (" — %d more to merge!"):format(3 - count)
			Candy.label(card, ("×%d%s"):format(count, need), { Font = F.small, TextColor3 = Color3.fromHex("#6E5C8F"), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 130) })
			Candy.label(card, Format.abbrev(income(g)) .. "/s each", { Font = F.body, TextColor3 = Color3.fromHex("#4DB52E"), Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 152) })
			local btnRow = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 56), Position = UDim2.new(0, 8, 1, -64), Parent = card })
			Candy.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = btnRow })
			if not autoOn and count >= 3 and g.size < 3 then
				Candy.button(btnRow, "Merge", "success", UDim2.new(0.5, -4, 1, 0), function()
					Net.send("MergeRequest", g.s, g.size, g.glitter)
				end)
			end
			local uid = g.uids[#g.uids]
			local risky = g.size >= 2 or (table.find(Z.Rarities, sp.rarity) or 1) >= 4
			local label = if confirmUid == uid then "Sure?" else "Release"
			Candy.button(btnRow, label, if confirmUid == uid then "primary" else "secondary", UDim2.new(0.5, -4, 1, 0), function()
				if risky and confirmUid ~= uid then
					confirmUid = uid
					draw()
					return
				end
				confirmUid = nil
				Net.send("ReleaseSquishy", uid)
			end)
		end
	end
	local select = Candy.tabs(modal.body, { "Income", "Rarity", "Newest" }, function(name)
		sortBy = name
		draw()
	end)
	select(sortBy)
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
		("Glitter: %g%% of every catch, ×%d income."):format(Z.GlitterChance * 100, Z.GlitterMult),
		"No Robux purchase changes any odds.",
	}
	for k, t in notes do
		local r = row(list, 10 + k, 64)
		Candy.label(r, t, { Font = F.small, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6) })
	end
end

------------------------------------------------------------------ Shelf Full
local fullGui: ScreenGui? = nil
local function shelfFull(newCard: any, lowCard: any?, seconds: number)
	if not fullGui then
		fullGui = Candy.screen("ShelfFull", 25)
	end
	local gui = fullGui :: ScreenGui
	gui:ClearAllChildren()
	if not newCard then
		return -- the server shelved it after all (space freed up)
	end
	local scale = Candy.make("UIScale", { Parent = gui })
	scale.Scale = (gui.Parent and 1) or 1
	local root = Candy.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 470), BackgroundColor3 = P.white, Parent = gui })
	Candy.corner(root, 22)
	Candy.stroke(root, 4)
	local title = Candy.label(root, "Shelf full!", { Font = F.header, TextColor3 = P.pink, Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 14) })
	Candy.textStroke(title, 2)
	local function card(x: number, c: any, caption: string)
		local f = Candy.pill(root, UDim2.fromOffset(300, 250), P.cream, { Position = UDim2.fromOffset(x, 84) })
		Candy.corner(f, 18)
		Candy.label(f, caption, { Font = F.small, Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 8) })
		local th = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 140), Position = UDim2.fromOffset(0, 34), Parent = f })
		Panels.thumb(th, c.s, c.size, c.glitter)
		local sp = S.ById[c.s]
		Candy.label(f, (if c.size > 1 then S.SizeNames[c.size] .. " " else "") .. sp.name .. (if c.glitter then " ✨" else ""), { Font = F.header, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 176) })
		Candy.label(f, Format.abbrev(sp.income * S.SizeMult[c.size] * (if c.glitter then Z.GlitterMult else 1)) .. "/s", { Font = F.body, TextColor3 = Color3.fromHex("#4DB52E"), Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 210) })
	end
	card(40, newCard, "New squishy")
	if lowCard then
		card(360, lowCard, "Your lowest earner")
	end
	local done = false
	local function choose(keep: boolean)
		if done then
			return
		end
		done = true
		Net.send("ShelfFullChoice", keep, newCard.uid)
		gui:ClearAllChildren()
	end
	local timer = Candy.label(root, "", { Font = F.small, TextColor3 = Color3.fromHex("#6E5C8F"), Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 20, 1, -116) })
	Candy.button(root, "Keep new", "success", UDim2.fromOffset(290, 72), function()
		choose(true)
	end, { Position = UDim2.new(0, 40, 1, -90) })
	Candy.button(root, "Release new", "secondary", UDim2.fromOffset(290, 72), function()
		choose(false)
	end, { Position = UDim2.new(0, 370, 1, -90) })
	local t0 = os.clock()
	task.spawn(function()
		while not done and root.Parent do
			local left = math.max(0, seconds - (os.clock() - t0))
			timer.Text = ("Auto-pick in %ds: keeps the higher earner"):format(math.ceil(left))
			if left <= 0 then
				done = true
				gui:ClearAllChildren()
				break
			end
			task.wait(0.2)
		end
	end)
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

	Net.listen("ShelfFull", shelfFull)
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
	for _, a in { "goo", "gloves", "slotUpgrades", "shelfLevel", "autoMerge", "ShelfCount" } do
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
		local sig = table.concat({
			tostring(nextGoo ~= nil and coins >= nextGoo.cost),
			tostring(nextGlove ~= nil and coins >= nextGlove.cost),
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
