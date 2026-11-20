--!strict
-- HUD (DESIGN 7.2): stat pills, menu buttons, FLING with its power ring, SQUEEZE with its ready
-- ring, Auto-Merge chip, hint chip, announcement banner. Other modules drive it through the API.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Kit.Net)
local Candy = require(script.Parent.Candy)

local P, F = Theme.Palette, Theme.Fonts
local E = Config.Economy
local player = Players.LocalPlayer

local Hud = {}
Hud.buttons = {} :: { [string]: GuiObject }
Hud.panels = {} :: { [string]: (string?) -> () } -- name -> open(tab)
Hud.ready = false

local gui: ScreenGui
local coinsLabel: TextLabel
local rateLabel: TextLabel
local shelfLabel: TextLabel
local spLabel: TextLabel
local hintChip: Frame
local hintLabel: TextLabel
local flingRing: { Frame } = {}
local squeezeRing: { Frame } = {}
local flingLabel: TextLabel
local awayPill: Frame
local squeezeLabel: TextLabel
local autoChip: Candy.Button
local banner: Frame
local bannerLabel: TextLabel

local RING = 40

-- a ring of segments around a circle; returns the segment frames
local function ring(parent: GuiObject, diameter: number, thickness: number): { Frame }
	local segs = {}
	local r = diameter / 2 + thickness / 2 + 4
	for i = 1, RING do
		local a = (i - 0.5) / RING * math.pi * 2 - math.pi / 2
		local seg = Candy.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(thickness, math.ceil(2 * math.pi * r / RING) + 2),
			Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r),
			Rotation = math.deg(a),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromHex("#E8E1F5"),
			ZIndex = 0,
			Parent = parent,
		})
		table.insert(segs, seg)
	end
	return segs
end

local function chargeColor(f: number): Color3
	if f < 0.5 then
		return P.lime:Lerp(P.lemon, f / 0.5)
	end
	return P.lemon:Lerp(P.pink, (f - 0.5) / 0.5)
end

-- fill the FLING ring to `charge` (0..1); the sweet spot segments are always gold
function Hud.setCharge(charge: number)
	for i, seg in flingRing do
		local f = (i - 0.5) / RING
		local sweet = f >= Config.Game.SweetSpot
		if f <= charge then
			seg.BackgroundColor3 = if sweet then P.lemon else chargeColor(f)
			seg.BackgroundTransparency = 0
		else
			seg.BackgroundColor3 = if sweet then Color3.fromHex("#FFE89A") else Color3.fromHex("#E8E1F5")
			seg.BackgroundTransparency = 0
		end
	end
end

-- "ready" | "away" | "busy" | "loading"
function Hud.setFlingState(state: string)
	local fling = Hud.buttons.Fling
	if not fling then
		return
	end
	fling.Visible = state ~= "away"
	awayPill.Visible = state == "away"
	local face = fling:FindFirstChild("Face") :: GuiObject?
	local lip = fling:FindFirstChild("Lip") :: GuiObject?
	if face and lip then
		local kind = if state == "ready" then Theme.Buttons.primary else Theme.Buttons.disabled
		face.BackgroundColor3 = kind[1]
		lip.BackgroundColor3 = kind[2]
	end
	flingLabel.Text = if state == "busy" then "Squishies incoming…" elseif state == "loading" then "Loading…" else "FLING"
	flingLabel.TextScaled = true
end

function Hud.setSqueeze(ready: number, total: number)
	squeezeLabel.Text = "SQUEEZE ×" .. ready
	local frac = if total > 0 then ready / total else 0
	for i, seg in squeezeRing do
		seg.BackgroundColor3 = if (i - 0.5) / RING <= frac then P.lime else Color3.fromHex("#E8E1F5")
	end
	local btn = Hud.buttons.Squeeze
	local pulsing = btn and btn:GetAttribute("Pulsing")
	if btn and total > 0 and frac >= 0.5 and not pulsing then
		btn:SetAttribute("Pulsing", true)
		local stop = Candy.pulse(btn)
		task.spawn(function()
			while btn:GetAttribute("Pulsing") do
				task.wait(0.2)
			end
			stop()
		end)
	elseif btn and (total == 0 or frac < 0.5) and pulsing then
		btn:SetAttribute("Pulsing", false)
	end
end

function Hud.hint(text: string?)
	hintChip.Visible = text ~= nil and text ~= ""
	hintLabel.Text = text or ""
	if text and text ~= "" then
		local s = hintChip:FindFirstChildOfClass("UIScale") or Candy.make("UIScale", { Parent = hintChip })
		s.Scale = 1.15
		TweenService:Create(s, Candy.POP, { Scale = 1 }):Play()
	end
end

function Hud.announce(text: string, color: Color3?)
	bannerLabel.Text = text
	banner.BackgroundColor3 = color or P.grape
	banner.Visible = true
	local s = banner:FindFirstChildOfClass("UIScale") or Candy.make("UIScale", { Parent = banner })
	s.Scale = 0.6
	TweenService:Create(s, Candy.POP, { Scale = 1 }):Play()
	local token = os.clock()
	banner:SetAttribute("Token", token)
	task.delay(4, function()
		if banner:GetAttribute("Token") == token then
			banner.Visible = false
		end
	end)
end

function Hud.coinTarget(): GuiObject
	return coinsLabel
end

local function statPill(parent: Instance, order: number, icon: string, w: number, h: number): (Frame, TextLabel)
	local pill = Candy.pill(parent, UDim2.fromOffset(w, h), P.white, { LayoutOrder = order })
	local ic = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(h - 12, h - 12), Position = UDim2.fromOffset(8, 6), Parent = pill })
	Candy.icon(ic, icon, { TextColor3 = P.ink })
	local l = Candy.label(pill, "", { Font = F.number, Size = UDim2.new(1, -h - 16, 1, -12), Position = UDim2.fromOffset(h + 2, 6), TextXAlignment = Enum.TextXAlignment.Left })
	return pill, l
end

function Hud.menuButton(name: string, icon: string, order: number, open: () -> ())
	local holder = gui:FindFirstChild("Menu") :: Frame
	local b = Candy.button(holder, "", "secondary", UDim2.fromOffset(88, 92), open, { LayoutOrder = order, Name = name })
	local ic = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(18, 8), Parent = b.face })
	Candy.icon(ic, icon)
	local l = Candy.label(b.face, name, { Font = F.header, TextColor3 = P.white, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 3, 1, -24) })
	Candy.textStroke(l, 1.5)
	local badge = Candy.pill(b.frame, UDim2.fromOffset(30, 30), P.pink, { Name = "Badge", Visible = false, Position = UDim2.new(1, -22, 0, -8), ZIndex = 5 })
	Candy.label(badge, "!", { Font = F.header, TextColor3 = P.white, ZIndex = 6 })
	Hud.buttons[name] = b.frame
end

function Hud.start()
	-- chat lives top-right so it never covers the stat pills (HANDBOOK 5)
	pcall(function()
		local cw = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if cw then
			cw.HorizontalAlignment = Enum.HorizontalAlignment.Right
			cw.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	end)

	gui = Candy.screen("Hud", 5)

	-- top-left stats
	local stats = Candy.make("Frame", { Name = "Stats", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 24), Size = UDim2.fromOffset(330, 260), Parent = gui })
	Candy.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })
	local _coinsPill: Frame
	_coinsPill, coinsLabel = statPill(stats, 1, "coin", 300, 64)
	coinsLabel.TextColor3 = P.ink
	rateLabel = Candy.label(stats, "+0/s", { LayoutOrder = 2, Font = F.number, TextColor3 = P.lime, Size = UDim2.fromOffset(280, 26), TextXAlignment = Enum.TextXAlignment.Left })
	Candy.textStroke(rateLabel, 2)
	local shelfPill
	shelfPill, shelfLabel = statPill(stats, 3, "squishy", 220, 52)
	local shelfBtn = Candy.make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = shelfPill })
	shelfBtn.Activated:Connect(function()
		local open = Hud.panels.Shelf
		if open then
			open()
		end
	end)
	local _spPill: Frame
	_spPill, spLabel = statPill(stats, 4, "sp", 300, 52)

	-- left menu column
	local menu = Candy.make("Frame", { Name = "Menu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.55, 0), Size = UDim2.fromOffset(92, 540), Parent = gui })
	Candy.make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = menu })

	-- FLING (bottom-centre)
	local d = if Candy.isTouch() then 220 else 190
	local fling = Candy.button(gui, "", "primary", UDim2.fromOffset(d, d + Theme.Lip), nil, { Name = "Fling", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40) })
	for _, c in fling.frame:GetDescendants() do
		if c:IsA("UICorner") then
			c.CornerRadius = UDim.new(0.5, 0)
		end
	end
	fling.label:Destroy()
	flingLabel = Candy.label(fling.face, "FLING", { Font = F.header, TextColor3 = P.white, Size = UDim2.new(0.8, 0, 0.3, 0), Position = UDim2.fromScale(0.1, 0.35) })
	Candy.textStroke(flingLabel, 3)
	flingRing = ring(fling.face, d, 16)
	Hud.buttons.Fling = fling.frame
	Hud.flingFace = fling.face
	Hud.setCharge(0)

	awayPill = Candy.pill(gui, UDim2.fromOffset(380, 70), P.pink, { Name = "BackHome", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60), Visible = false })
	local away = Candy.label(awayPill, "⬆ Back to your slingshot", { Font = F.header, TextColor3 = P.white, Size = UDim2.new(1, -24, 1, -16), Position = UDim2.fromOffset(12, 8) })
	Candy.textStroke(away, 2)
	local awayBtn = Candy.make("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = awayPill })
	awayBtn.Activated:Connect(function()
		Net.send("GoHome")
	end)

	-- SQUEEZE (bottom-right) + Auto-Merge chip
	local sq = Candy.button(gui, "", "secondary", UDim2.fromOffset(150, 150 + Theme.Lip), function()
		Hud.onSqueeze()
	end, { Name = "Squeeze", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -60, 1, -50) })
	for _, c in sq.frame:GetDescendants() do
		if c:IsA("UICorner") then
			c.CornerRadius = UDim.new(0.5, 0)
		end
	end
	sq.label:Destroy()
	squeezeLabel = Candy.label(sq.face, "SQUEEZE ×0", { Font = F.header, TextColor3 = P.white, Size = UDim2.new(0.84, 0, 0.3, 0), Position = UDim2.fromScale(0.08, 0.35) })
	Candy.textStroke(squeezeLabel, 2)
	squeezeRing = ring(sq.face, 150, 12)
	Hud.buttons.Squeeze = sq.frame

	autoChip = Candy.button(gui, "Auto-Merge: ON", "success", UDim2.fromOffset(220, 52), function()
		Net.send("SetAutoMerge", player:GetAttribute("autoMerge") == false)
	end, { Name = "AutoMerge", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -232) })
	Hud.buttons.AutoMerge = autoChip.frame

	-- top-centre hint chip + announcement banner
	hintChip = Candy.pill(gui, UDim2.fromOffset(640, 60), P.white, { Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Visible = false })
	hintLabel = Candy.label(hintChip, "", { Font = F.header, Size = UDim2.new(1, -32, 1, -16), Position = UDim2.fromOffset(16, 8) })
	banner = Candy.pill(gui, UDim2.fromOffset(820, 70), P.grape, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Visible = false })
	bannerLabel = Candy.label(banner, "", { Font = F.header, TextColor3 = P.white, Size = UDim2.new(1, -32, 1, -16), Position = UDim2.fromOffset(16, 8) })
	Candy.textStroke(bannerLabel, 2)

	-- live stats
	local function refresh()
		local coins = (player:GetAttribute("coins") :: number?) or 0
		Candy.countTo(coinsLabel, coins)
		rateLabel.Text = "+" .. Format.abbrev((player:GetAttribute("IncomePerSec") :: number?) or 0) .. "/s"
		shelfLabel.Text = ("%d / %d"):format((player:GetAttribute("ShelfCount") :: number?) or 0, (player:GetAttribute("Slots") :: number?) or E.Slots.start)
		local gloves = (player:GetAttribute("gloves") :: number?) or 1
		spLabel.Text = ("SP %s (+%d/fling)"):format(Format.abbrev((player:GetAttribute("sp") :: number?) or 1), E.Gloves[gloves].sp)
		local on = player:GetAttribute("autoMerge") ~= false
		autoChip.setText(if on then "Auto-Merge: ON" else "Auto-Merge: OFF")
		autoChip.setKind(if on then "success" else "disabled")
	end
	for _, a in { "coins", "IncomePerSec", "ShelfCount", "Slots", "sp", "gloves", "autoMerge" } do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()

	Net.listen("Announce", function(text: string, rarity: string)
		local hex = Config.Zones.RarityColors[rarity]
		Hud.announce(text, if hex then Color3.fromHex(hex) else nil)
	end)
	Hud.ready = true
end

-- set by the Shelf view (it knows which squishies are ready)
Hud.onSqueeze = function()
	Net.send("SqueezeRequest")
end
Hud.flingFace = nil :: GuiObject?

return Hud
