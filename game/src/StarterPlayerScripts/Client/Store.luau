--!strict
-- The Shop (DESIGN 7.3, 10): Passes | Coins tabs, the Auto-Fling / Auto-Squeeze HUD toggles for
-- owners, the Squish Party pill, purchase toasts and the Rainbow Trail on owners' goo.
-- Items with no id in this universe show "Coming soon" (Studio grants them free so they can be tested).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Products = require(ReplicatedStorage.Kit.Products)
local Net = require(ReplicatedStorage.Kit.Net)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local P, F = Theme.Palette, Theme.Fonts
local Mo = Config.Monetization
local player = Players.LocalPlayer
local MUTED = Color3.fromHex("#6E5C8F")

local Store = {}
local redraw: (() -> ())? = nil

-- picture + one colour per item (the card's stripe and the button)
local LOOK: { [string]: { icon: string, color: Color3 } } = {
	coins_2x = { icon = "pass_coins", color = P.lemon },
	auto_fling = { icon = "pass_fling", color = P.pink },
	auto_squeeze = { icon = "pass_squeeze", color = P.sky },
	rainbow_trail = { icon = "pass_rainbow", color = P.grape },
	coin_bag = { icon = "coin_bag", color = P.lemon },
	coin_jar = { icon = "coin_jar", color = P.lemon },
	coin_tub = { icon = "coin_tub", color = P.lemon },
	squish_party = { icon = "party", color = P.pink },
}

local function owns(key: string): boolean
	return player:GetAttribute(Products.passAttribute(key)) == true
end

-- false when the item can't be bought in this universe yet (Studio still grants it free)
local function onSale(kind: string, key: string): boolean
	return Products.id(kind :: any, key) ~= 0 or RunService:IsStudio()
end

local function partyLeft(): number
	local u = (workspace:GetAttribute("PartyUntil") :: number?) or 0
	return math.max(0, u - workspace:GetServerTimeNow())
end

local function mmss(s: number): string
	s = math.ceil(s)
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function packAmount(key: string): number
	local p = Mo.CoinPacks[key]
	local base = (player:GetAttribute("BaseIncome") :: number?) or 0
	return math.floor(math.max(p.floor, base * p.minutes * 60))
end

------------------------------------------------------------------ cards
local function card(parent: Instance, order: number, key: string, kind: string): Frame
	local item = Products.get(kind :: any, key) :: any
	local look = LOOK[key]
	local f = Candy.pill(parent, UDim2.fromOffset(0, 0), P.cream, { LayoutOrder = order, Name = key })
	-- the pill sized its corner from a 0 height (grid cells); round it like the other cards
	local corner = f:FindFirstChildOfClass("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0, 18)
	local stroke = f:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = look.color:Lerp(P.ink, 0.25) -- keep the pill's 3 px: the scroll pads for 3
	local pic = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(14, 14), Parent = f })
	Candy.icon(pic, look.icon, { TextColor3 = P.ink, TextScaled = true })
	Candy.label(f, item.name, { Font = F.header, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -136, 0, 36), Position = UDim2.fromOffset(122, 14) })
	Candy.label(f, item.description, {
		Name = "Desc",
		Font = F.small,
		TextColor3 = MUTED,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -136, 0, 54),
		Position = UDim2.fromOffset(122, 54),
	})
	Candy.make("UITextSizeConstraint", { MaxTextSize = 17, Parent = f:FindFirstChild("Desc") })
	return f
end

local function buyButton(f: Frame, key: string, kind: string, text: string?, disabled: boolean?)
	local item = Products.get(kind :: any, key) :: any
	local sale = onSale(kind, key)
	local label = text or (if sale then "R$ " .. item.price else "Coming soon")
	local b = Candy.button(f, label, if sale and not disabled then "success" else "disabled", UDim2.new(1, -28, 0, 54), function()
		if not sale or disabled then
			Sound.play("ui_error")
			return
		end
		Net.send("Kit.Buy", key)
	end, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14) })
	if not sale or disabled then
		b.setKind("disabled")
	end
end

local function passesInto(list: Instance)
	Candy.make("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 204), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local passes = Products.list("passes")
	for i, e in passes do
		-- dearest first: 2x Coins leads
		local f = card(list, #passes - i + 1, e.key, "passes")
		if owns(e.key) then
			local b = Candy.button(f, "Owned", "secondary", UDim2.new(1, -28, 0, 54), function() end, { Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14) })
			b.setKind("secondary")
		else
			buyButton(f, e.key, "passes")
		end
	end
end

local function coinsInto(list: Instance)
	Candy.make("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 204), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, e in Products.list("products") do
		local f = card(list, i, e.key, "products")
		if Mo.CoinPacks[e.key] then
			-- the exact amount this player gets right now
			local amt = Candy.label(f, "+" .. Format.abbrev(packAmount(e.key)) .. " coins", {
				Name = "Amount",
				Font = F.number,
				TextColor3 = Color3.fromHex("#4DB52E"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				Size = UDim2.new(1, -136, 0, 28),
				Position = UDim2.fromOffset(122, 108),
			})
			amt.ZIndex = 2
			buyButton(f, e.key, "products")
		else
			-- Squish Party: the live timer; full at the 30 min cap
			local left = partyLeft()
			local full = left > (Mo.PartyMaxMinutes - Mo.PartyMinutes) * 60
			Candy.label(f, if left > 0 then "Party on: " .. mmss(left) .. " left" else "No party right now", {
				Name = "Timer",
				Font = F.header,
				TextColor3 = if left > 0 then P.pink else MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				Size = UDim2.new(1, -136, 0, 28),
				Position = UDim2.fromOffset(122, 108),
			})
			buyButton(f, e.key, "products", if full then "Party is full" else nil, full)
		end
	end
end

function Store.open(tab: string?)
	local modal = Candy.modal("Shop", "SHOP")
	local content = Candy.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = modal.body })
	local current = if tab == "Coins" then "Coins" else "Passes"
	local function draw()
		content:ClearAllChildren()
		local list = Candy.scroll(content)
		if current == "Passes" then
			passesInto(list)
		else
			coinsInto(list)
		end
	end
	local select = Candy.tabs(modal.body, { "Passes", "Coins" }, function(name)
		current = name
		draw()
	end)
	redraw = draw
	select(current)
end

local function redrawIfOpen()
	if redraw and Candy.modalOpen() == "Shop" then
		(redraw :: () -> ())()
	end
end

------------------------------------------------------------------ HUD: auto toggles + party pill
local autoChips: { [string]: Candy.Button } = {}

local function autoChip(which: string, pass: string, label: string, y: number)
	local holder = Hud.gui()
	local b = Candy.button(holder, label, "disabled", UDim2.fromOffset(220, 52), function()
		local attr = if which == "fling" then "AutoFling" else "AutoSqueeze"
		Net.send("SetAuto", which, player:GetAttribute(attr) ~= true)
	end, { Name = "Auto" .. which, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, y), Visible = false })
	autoChips[which] = b
	Hud.buttons["Auto" .. which] = b.frame
	local function refresh()
		local attr = if which == "fling" then "AutoFling" else "AutoSqueeze"
		local on = player:GetAttribute(attr) == true
		b.frame.Visible = owns(pass)
		b.setText(label .. (if on then ": ON" else ": OFF"))
		b.setKind(if on then "success" else "disabled")
	end
	player:GetAttributeChangedSignal(if which == "fling" then "AutoFling" else "AutoSqueeze"):Connect(refresh)
	player:GetAttributeChangedSignal(Products.passAttribute(pass)):Connect(refresh)
	refresh()
end

local function partyPill()
	local gui = Hud.gui()
	local pill = Candy.pill(gui, UDim2.fromOffset(400, 58), P.pink, { Name = "Party", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(if Candy.isTouch() then 220 else 190) - Theme.Lip - 54), Visible = false })
	local l = Candy.label(pill, "", { Font = F.header, TextColor3 = P.white, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6) })
	Candy.textStroke(l, 2)
	Candy.make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4FA3")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FF8A3D")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#9B5CFF")),
		}),
		Parent = pill,
	})
	task.spawn(function()
		local last = -1
		while true do
			local left = partyLeft()
			pill.Visible = left > 0
			if left > 0 then
				l.Text = "SQUISH PARTY! 2x coins  " .. mmss(left)
			end
			local whole = math.ceil(left)
			if whole ~= last then
				last = whole
				if Candy.modalOpen() == "Shop" and whole % 5 == 0 then
					redrawIfOpen()
				end
			end
			task.wait(0.25)
		end
	end)
end

------------------------------------------------------------------ Rainbow Trail on goo
-- Flight calls this for every goo blob it makes
function Store.decorateGoo(owner: number, blob: Model)
	local p = Players:GetPlayerByUserId(owner)
	if not p or p:GetAttribute(Products.passAttribute("rainbow_trail")) ~= true then
		return
	end
	local core = blob.PrimaryPart or blob:FindFirstChildWhichIsA("BasePart")
	if not core then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.new(0, 0.8, 0)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.new(0, -0.8, 0)
	a1.Parent = core
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Lifetime = 0.6
	t.LightEmission = 0.4
	t.FaceCamera = true
	t.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4F6E")),
		ColorSequenceKeypoint.new(0.2, Color3.fromHex("#FF9A3D")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("#FFE14D")),
		ColorSequenceKeypoint.new(0.6, Color3.fromHex("#7CF25A")),
		ColorSequenceKeypoint.new(0.8, Color3.fromHex("#3EC5FF")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#B36BFF")),
	})
	t.Transparency = NumberSequence.new(0.1, 1)
	t.WidthScale = NumberSequence.new(1, 0.2)
	t.Parent = core
end

------------------------------------------------------------------ wiring
function Store.start()
	while not Hud.ready do
		task.wait()
	end
	Hud.panels.Shop = Store.open
	Hud.menuButton("Shop", "shop", 1, function()
		Store.open()
	end)
	-- stacked above the Auto-Merge chip (bottom-right)
	autoChip("squeeze", "auto_squeeze", "Auto-Squeeze", -292)
	autoChip("fling", "auto_fling", "Auto-Throw", -352)
	partyPill()

	Net.listen("Kit.Purchased", function(kind: string, key: string)
		local item = Products.get(kind :: any, key) :: any
		Sound.play("buy")
		if kind == "passes" then
			Candy.toast(("%s unlocked!"):format(item and item.name or key), P.lime)
		elseif Mo.CoinPacks[key] then
			Candy.toast(("%s: coins added!"):format(item and item.name or key), P.lemon)
			local b = Hud.buttons.Shop
			if b then
				Candy.flyCoins(b.AbsolutePosition + b.AbsoluteSize / 2, Hud.coinTarget(), 8)
			end
		end
		redrawIfOpen()
	end)
	for _, e in Products.list("passes") do
		player:GetAttributeChangedSignal(Products.passAttribute(e.key)):Connect(redrawIfOpen)
	end
	player:GetAttributeChangedSignal("BaseIncome"):Connect(function()
		-- coin card amounts follow income, but not every tick
		redrawIfOpen()
	end)
end

return Store
