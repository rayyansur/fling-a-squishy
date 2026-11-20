--!strict
-- PR 2 screens (DESIGN 7.3, 7.4): Squishydex (+ Odds tab), Daily (calendar + quests), Re-Squish
-- (checklist, confirm, goo wipe), Settings, the Welcome-back modal, and the HUD buttons for them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Kit.Net)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Candy = require(script.Parent.Candy)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)
local Panels = require(script.Parent.Panels)

local P, F = Theme.Palette, Theme.Fonts
local E, S, Z, Pr = Config.Economy, Config.Squishies, Config.Zones, Config.Progress
local player = Players.LocalPlayer
local MUTED = Color3.fromHex("#6E5C8F")

local Menus = {}
local dex: { [string]: any } = {}
local daily: any = nil
local redraw: { [string]: () -> () } = {}

local function attr(name: string, default: any): any
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function card(parent: Instance, size: UDim2, color: Color3?, props: { [string]: any }?): Frame
	local f = Candy.pill(parent, size, color or P.cream, props)
	Candy.corner(f, 18)
	return f
end

local function redrawIfOpen(name: string)
	local fn = redraw[name]
	if fn and Candy.modalOpen() == name then
		fn()
	end
end

------------------------------------------------------------------ Squishydex
local function dexCard(parent: Instance, order: number, sp: any)
	local entry = dex[sp.id]
	local rc = Color3.fromHex(Z.RarityColors[sp.rarity])
	local f = card(parent, UDim2.fromOffset(0, 0), P.cream, { LayoutOrder = order, Name = sp.id })
	Candy.stroke(f, 3, rc)
	local th = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.fromScale(0, 0.03), Parent = f })
	local vp = Panels.thumb(th, sp.id, if entry then entry.best else 1, entry and entry.glitter)
	if not entry then
		vp.ImageColor3 = Color3.fromRGB(60, 45, 95) -- silhouette
	end
	Candy.label(f, if entry then sp.name else "???", { Font = F.header, TextScaled = true, Size = UDim2.new(1, -12, 0.15, 0), Position = UDim2.fromScale(0, 0.6) + UDim2.fromOffset(6, 0) })
	Candy.label(f, if entry then ("%s/s · ×%d"):format(Format.abbrev(sp.income), entry.n) else sp.rarity, {
		Font = F.small,
		TextColor3 = if entry then Color3.fromHex("#4DB52E") else rc:Lerp(P.ink, 0.3),
		TextScaled = true,
		Size = UDim2.new(1, -12, 0.12, 0),
		Position = UDim2.fromScale(0, 0.77) + UDim2.fromOffset(6, 0),
	})
	if entry then
		local badge = card(f, UDim2.fromOffset(34, 26), rc, { Position = UDim2.fromOffset(8, 8) })
		local l = Candy.label(badge, ({ "N", "C", "M" })[entry.best] or "N", { Font = F.header, TextColor3 = P.white })
		Candy.textStroke(l, 1.5)
		if entry.glitter then
			Candy.label(f, "✨", { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4) })
		end
	end
end

function Menus.dex(tab: string?)
	local modal = Candy.modal("Dex", "SQUISHYDEX")
	local content = Candy.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = modal.body })
	local current = tab or "Squishydex"
	local function draw()
		content:ClearAllChildren()
		local caught = 0
		for _ in dex do
			caught += 1
		end
		modal.title.Text = ("SQUISHYDEX  %d / %d"):format(caught, #S.List)
		if current == "Odds" then
			Panels.oddsInto(content)
			return
		end
		local list = Candy.scroll(content)
		Candy.make("UIGridLayout", { CellSize = UDim2.new(0.25, -12, 0, 196), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		for i, sp in S.List do
			dexCard(list, i, sp)
		end
	end
	local select = Candy.tabs(modal.body, { "Squishydex", "Odds" }, function(name)
		current = name
		draw()
	end)
	redraw.Dex = draw
	select(current)
	Net.send("DexRequest")
end

------------------------------------------------------------------ Daily
local function rewardText(i: number): string
	local r: any = Pr.Daily[i]
	if r.kind == "coins" then
		return Format.abbrev(if daily then daily.tiles[i] else r.min) .. " coins"
	elseif r.kind == "sp" then
		return ("+%d SP"):format(r.amount)
	elseif r.kind == "squishy" then
		return "Free " .. r.rarity .. " squishy"
	end
	return ("Epic %d%% · Legend. %d%% · Mythic %d%%"):format(r.odds.Epic, r.odds.Legendary, r.odds.Mythic)
end

function Menus.daily()
	local modal = Candy.modal("Daily", "DAILY")
	local function draw()
		modal.body:ClearAllChildren()
		if not daily then
			Candy.label(modal.body, "Loading…", { Font = F.header })
			return
		end
		local d = daily
		-- calendar
		local cal = Candy.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), Parent = modal.body })
		Candy.make("UIGridLayout", { CellSize = UDim2.new(1 / 7, -10, 1, 0), CellPadding = UDim2.fromOffset(10, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cal })
		for i = 1, 7 do
			local done = if d.canClaim then i < d.nextDay else i <= d.cycleDay
			local today = d.canClaim and i == d.nextDay
			local f = card(cal, UDim2.fromOffset(0, 0), if today then P.lemon elseif done then Color3.fromHex("#E4F9DA") else P.cream, { LayoutOrder = i, Name = "Day" .. i })
			if today then
				Candy.stroke(f, 4, P.pink)
			end
			Candy.label(f, "Day " .. i, { Font = F.header, Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 8) })
			Candy.label(f, rewardText(i), { Font = F.small, TextWrapped = true, TextScaled = true, Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 44) })
			if done then
				Candy.label(f, "✓", { Font = F.header, TextColor3 = Color3.fromHex("#4DB52E"), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -48) })
			end
		end
		local streak = Candy.label(modal.body, ("Streak: %d day%s"):format(d.streak, if d.streak == 1 then "" else "s"), {
			Font = F.header, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0, 40), Position = UDim2.fromOffset(4, 214),
		})
		streak.TextColor3 = P.ink
		Candy.button(modal.body, if d.canClaim then "Claim day " .. d.nextDay else "Come back tomorrow", if d.canClaim then "success" else "disabled", UDim2.fromOffset(330, 64), function()
			if d.canClaim then
				Net.send("ClaimDaily")
			else
				Sound.play("ui_error")
			end
		end, { Name = "ClaimDaily", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 206) })
		-- quests
		local ql = Candy.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 290), Size = UDim2.new(1, 0, 1, -290), Parent = modal.body })
		Candy.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ql })
		for i, q in d.quests do
			local f = card(ql, UDim2.new(1, 0, 0, 78), P.cream, { LayoutOrder = i, Name = "Quest" .. i })
			Candy.label(f, q.text, { Font = F.header, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 30), Position = UDim2.fromOffset(16, 8) })
			local bar = card(f, UDim2.new(1, -330, 0, 22), Color3.fromHex("#E8E1F5"), { Position = UDim2.fromOffset(16, 44) })
			local fill = card(bar, UDim2.new(math.clamp(q.n / q.goal, 0, 1), 0, 1, 0), P.lime)
			fill.ZIndex = bar.ZIndex + 1
			Candy.label(bar, ("%d / %d"):format(q.n, q.goal), { Font = F.small, ZIndex = bar.ZIndex + 2 })
			local ready = q.n >= q.goal and not q.claimed
			local b = Candy.button(f, if q.claimed then "Done" else Format.abbrev(d.questReward), if ready then "success" elseif q.claimed then "secondary" else "disabled", UDim2.fromOffset(220, 60), function()
				if ready then
					Net.send("ClaimQuest", i)
				else
					Sound.play("ui_error")
				end
			end, { Name = "Claim", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
			if not q.claimed then
				Candy.buttonIcon(b, "coin")
			end
		end
	end
	redraw.Daily = draw
	draw()
	Net.send("DailyRequest")
end

------------------------------------------------------------------ Re-Squish
local function check(parent: Instance, y: number, ok: boolean, text: string)
	local f = card(parent, UDim2.new(1, 0, 0, 56), if ok then Color3.fromHex("#E4F9DA") else P.cream, { Position = UDim2.fromOffset(0, y) })
	Candy.label(f, if ok then "✓" else "✗", { Font = F.header, TextColor3 = if ok then Color3.fromHex("#4DB52E") else P.pink, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(10, 8) })
	Candy.label(f, text, { Font = F.body, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -70, 1, -12), Position = UDim2.fromOffset(56, 6) })
end

function Menus.reSquish()
	local modal = Candy.modal("ReSquish", "RE-SQUISH")
	local confirming = false
	local function draw()
		modal.body:ClearAllChildren()
		local n = attr("reSquishes", 0)
		local cost = attr("ReSquishCost", E.reSquishCost(n + 1))
		local coins = attr("coins", 0)
		local legOk = attr("ReSquishLegendary", false)
		local ready = coins >= cost and legOk
		check(modal.body, 0, coins >= cost, ("Have %s coins (%s now)"):format(Format.abbrev(cost), Format.abbrev(math.floor(coins))))
		check(modal.body, 66, legOk, "A Legendary or Mythic squishy on your shelf")
		local info = card(modal.body, UDim2.new(1, 0, 0, 200), P.white, { Position = UDim2.fromOffset(0, 136) })
		Candy.stroke(info, 3, P.grape)
		local inc0, inc1 = 1 + E.ReSquish.incomePer * n, 1 + E.ReSquish.incomePer * (n + 1)
		local d0, d1 = 1 + E.ReSquish.distPer * n, 1 + E.ReSquish.distPer * (n + 1)
		Candy.label(info, ("Income ×%g → ×%g   ·   Fling distance ×%g → ×%g"):format(inc0, inc1, d0, d1), { Font = F.header, TextColor3 = P.grape, Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 10) })
		Candy.label(info, "Resets: coins, Sling Power, goo, gloves, every squishy on your shelf, slots, shelf level.", { Font = F.small, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 58) })
		Candy.label(info, "Keeps: Squishydex, Re-Squish count, badges, passes, daily streak, stats, Auto-Merge.", { Font = F.small, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 122) })
		if confirming then
			local c = card(modal.body, UDim2.new(1, 0, 0, 150), P.cream, { Position = UDim2.new(0, 0, 1, -150) })
			Candy.label(c, Pr.ReSquishConfirm, { Font = F.header, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 10) })
			Candy.button(c, "Re-Squish!", "grape", UDim2.fromOffset(260, 66), function()
				confirming = false
				modal.close()
				Net.send("ReSquish")
			end, { Name = "Confirm", Position = UDim2.new(0.5, -280, 0, 66) })
			Candy.button(c, "Not yet", "secondary", UDim2.fromOffset(260, 66), function()
				confirming = false
				draw()
			end, { Name = "Cancel", Position = UDim2.new(0.5, 20, 0, 66) })
		else
			Candy.button(modal.body, "RE-SQUISH!", if ready then "grape" else "disabled", UDim2.fromOffset(420, 84), function()
				if ready then
					confirming = true
					draw()
				else
					Sound.play("ui_error")
				end
			end, { Name = "ReSquishGo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10) })
		end
	end
	redraw.ReSquish = function()
		if not confirming then
			draw()
		end
	end
	draw()
end

-- full-screen pink goo wipe (1.5 s) after a Re-Squish
local function wipe(n: number)
	local gui = Candy.screen("GooWipe", 40)
	gui.IgnoreGuiInset = true
	local goo = Candy.make("Frame", { BackgroundColor3 = P.pink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, -1.2), Size = UDim2.fromScale(1.2, 1.2), Parent = gui })
	for i = 1, 9 do
		local drip = Candy.make("Frame", { BackgroundColor3 = P.pink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.22), Position = UDim2.fromScale((i - 0.5) / 9, 1 + (i % 3) * 0.04), Parent = goo })
		Candy.make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = drip })
	end
	local l = Candy.label(goo, "RE-SQUISH " .. Format.roman(n) .. "!", { Font = F.header, TextColor3 = P.white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.6, 0.12) })
	Candy.textStroke(l, 4)
	Sound.sting("resquish_sting")
	local down = TweenService:Create(goo, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, -0.1) })
	down:Play()
	task.delay(0.95, function()
		local up = TweenService:Create(goo, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 1.2) })
		up.Completed:Once(function()
			gui:Destroy()
		end)
		up:Play()
	end)
end

------------------------------------------------------------------ Settings
function Menus.applySettings()
	Sound.setEnabled(attr("SetMusic", true), attr("SetSfx", true))
	local low = attr("SetLow", false)
	for _, c in Lighting:GetChildren() do
		if c:IsA("BloomEffect") then
			c.Enabled = not low
		end
	end
end

function Menus.settings()
	local modal = Candy.modal("Settings", "SETTINGS", 700, 460)
	local function draw()
		modal.body:ClearAllChildren()
		local rows = {
			{ key = "SetMusic", name = "Music", default = true },
			{ key = "SetSfx", name = "Sound effects", default = true },
			{ key = "SetLow", name = "Low graphics", default = false },
		}
		for i, r in rows do
			local on = attr(r.key, r.default)
			local f = card(modal.body, UDim2.new(1, 0, 0, 84), P.cream, { Position = UDim2.fromOffset(0, (i - 1) * 96), Name = r.key })
			Candy.label(f, r.name, { Font = F.header, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -240, 1, -16), Position = UDim2.fromOffset(18, 8) })
			Candy.button(f, if on then "ON" else "OFF", if on then "success" else "disabled", UDim2.fromOffset(180, 60), function()
				local v = {
					SetMusic = attr("SetMusic", true),
					SetSfx = attr("SetSfx", true),
					SetLow = attr("SetLow", false),
				}
				v[r.key] = not on
				Net.send("SettingsSave", v.SetMusic, v.SetSfx, v.SetLow)
			end, { Name = "Toggle", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
		end
	end
	redraw.Settings = draw
	draw()
end

------------------------------------------------------------------ Welcome back
local function welcomeBack(amount: number, secs: number)
	local modal = Candy.modal("WelcomeBack", "WELCOME BACK!", 720, 400)
	local h = secs / 3600
	local away = if h >= 1 then ("%.1f h"):format(h) else ("%d min"):format(math.floor(secs / 60))
	Candy.label(modal.body, ("Your squishies made %s coins while you were away (%s)."):format(Format.abbrev(amount), away), {
		Font = F.header, TextWrapped = true, Size = UDim2.new(1, 0, 0, 110),
	})
	Candy.label(modal.body, "50% rate, up to 6 h.", { Font = F.small, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 116) })
	local b
	b = Candy.button(modal.body, "Collect", "success", UDim2.fromOffset(300, 76), function()
		local f = b.frame :: GuiObject
		Candy.flyCoins(f.AbsolutePosition + f.AbsoluteSize / 2, Hud.coinTarget(), 8)
		Sound.play("coin_burst")
		modal.close()
	end, { Name = "Collect", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8) })
end

------------------------------------------------------------------ wiring
function Menus.start()
	while not Hud.ready do
		task.wait()
	end
	Hud.panels.Dex = Menus.dex
	Hud.panels.ReSquish = function()
		Menus.reSquish()
	end
	Hud.panels.Daily = function()
		Menus.daily()
	end
	Hud.panels.Settings = function()
		Menus.settings()
	end
	Hud.menuButton("Dex", "dex", 2, function()
		Menus.dex()
	end)
	Hud.menuButton("Daily", "daily", 5, function()
		Menus.daily()
	end)
	Hud.menuButton("Settings", "settings", 6, function()
		Menus.settings()
	end)
	Hud.reSquishButton(function()
		Menus.reSquish()
	end)
	Hud.setReSquishReady(attr("ReSquishReady", false) == true)

	Net.listen("DexState", function(d: any)
		dex = if type(d) == "table" then d else {}
		redrawIfOpen("Dex")
	end)
	Net.listen("DailyState", function(d: any)
		daily = d
		redrawIfOpen("Daily")
	end)
	Net.listen("DailyClaimed", function(text: string)
		Sound.play("buy")
		Candy.toast(text, P.grape)
	end)
	Net.listen("WelcomeBack", welcomeBack)
	Net.listen("ReSquished", wipe)
	Net.listen("Arrived", function()
		-- a new species may have joined the Dex
		if Candy.modalOpen() == "Dex" then
			Net.send("DexRequest")
		end
	end)

	local function daily_badge()
		local b = Hud.buttons.Daily
		local badge = b and b:FindFirstChild("Badge", true) :: GuiObject?
		if badge then
			badge.Visible = attr("DailyReady", false) == true
		end
	end
	player:GetAttributeChangedSignal("DailyReady"):Connect(daily_badge)
	daily_badge()

	for _, a in { "SetMusic", "SetSfx", "SetLow" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			Menus.applySettings()
			redrawIfOpen("Settings")
		end)
	end
	Menus.applySettings()
	for _, a in { "ReSquishReady", "ReSquishLegendary", "ReSquishCost", "reSquishes" } do
		player:GetAttributeChangedSignal(a):Connect(function()
			redrawIfOpen("ReSquish")
			Hud.setReSquishReady(attr("ReSquishReady", false) == true)
		end)
	end
	-- the coin line ticks every second; redraw the Re-Squish checklist at most every 2 s
	task.spawn(function()
		while true do
			task.wait(2)
			redrawIfOpen("ReSquish")
		end
	end)
end

return Menus
