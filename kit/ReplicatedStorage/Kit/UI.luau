--!strict
-- UI: small builders for readable, themed, touch-friendly client UI. Colours and font come from
-- Config.Theme (Kit.Types.Theme); every game sets its own. Client-only, but safe to require
-- anywhere (nothing runs until you call it).
--
--   local gui = UI.screen("Hud")
--   local coins = UI.text(UI.panel(gui, UDim2.fromOffset(180, 56), UDim2.fromOffset(16, 16)), "0")
--   UI.bindAttribute(coins, "Coins", function(v) return "Coins: " .. v end)
--   UI.hudButton("Store", StoreUI.open)
--   UI.toast("Saved!", "good")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local UI = {}

local DEFAULT: Types.Theme = {
	font = Enum.Font.GothamBold,
	bg = Color3.fromRGB(20, 22, 30),
	panel = Color3.fromRGB(34, 37, 50),
	text = Color3.fromRGB(245, 246, 250),
	subtext = Color3.fromRGB(170, 176, 196),
	accent = Color3.fromRGB(255, 196, 46),
	accentText = Color3.fromRGB(30, 24, 8),
	good = Color3.fromRGB(88, 214, 141),
	bad = Color3.fromRGB(240, 96, 96),
	corner = 12,
}

local resolved: { [string]: any }? = nil
function UI.theme(): { [string]: any }
	if not resolved then
		local custom = {}
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local cfg = shared and shared:FindFirstChild("Config")
		if cfg and cfg:IsA("ModuleScript") then
			custom = (require(cfg) :: any).Theme or {}
		end
		local t = {}
		for k, v in DEFAULT :: any do
			t[k] = if custom[k] ~= nil then custom[k] else v
		end
		resolved = t
	end
	return resolved :: any
end

function UI.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	local parent = nil
	local given: { [string]: any } = props or {}
	for k, v in given do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	local kids: { Instance } = children or {}
	for _, c in kids do
		c.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function round(inst: Instance, r: number?)
	UI.make("UICorner", { CornerRadius = UDim.new(0, r or UI.theme().corner), Parent = inst })
end

function UI.screen(name: string, order: number?): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return UI.make("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = order or 0, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
end

function UI.panel(parent: Instance, size: UDim2, pos: UDim2?, props: { [string]: any }?): Frame
	local t = UI.theme()
	local f = UI.make("Frame", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = t.panel, BorderSizePixel = 0, Parent = parent })
	local extra: { [string]: any } = props or {}
	for k, v in extra do
		f[k] = v
	end
	round(f)
	UI.make("UIStroke", { Color = t.bg, Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	UI.make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = f,
	})
	return f
end

function UI.text(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local t = UI.theme()
	local l = UI.make("TextLabel", {
		Text = text,
		Font = t.font,
		TextColor3 = t.text,
		TextSize = 20,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	local extra: { [string]: any } = props or {}
	for k, v in extra do
		l[k] = v
	end
	return l
end

function UI.button(parent: Instance, text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local t = UI.theme()
	local b = UI.make("TextButton", {
		Text = text,
		Font = t.font,
		TextSize = 20,
		TextColor3 = t.accentText,
		BackgroundColor3 = t.accent,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(140, 48), -- 44px+ for touch
		Parent = parent,
	})
	local extra: { [string]: any } = props or {}
	for k, v in extra do
		b[k] = v
	end
	round(b)
	local scale = UI.make("UIScale", { Parent = b })
	local info = TweenInfo.new(0.08)
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, info, { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, info, { Scale = 0.96 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	b.Activated:Connect(onClick)
	return b
end

function UI.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	return UI.make("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- keep a label in sync with a LocalPlayer attribute (Kit.Data mirrors save keys there)
function UI.bindAttribute(label: TextLabel, attr: string, format: ((any) -> string)?)
	local player = Players.LocalPlayer
	local function refresh()
		local v = player:GetAttribute(attr)
		label.Text = if format then format(v or 0) else tostring(v or 0)
	end
	player:GetAttributeChangedSignal(attr):Connect(refresh)
	refresh()
end

-- A ScrollingFrame clips at its edges, and a UIStroke (Border) is drawn OUTSIDE its frame, so a
-- stroked card at (0, 0) loses its outline (plus hover/press scale pokes out). UI.scroll insets
-- the content so that can't happen. Use it for every scrolling body. tools/studio/ui_audit.luau
-- reports any child that still gets clipped.
UI.INSET = 8
function UI.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = UI.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	local extra: { [string]: any } = props or {}
	for k, v in extra do
		s[k] = v
	end
	UI.make("UIPadding", {
		PaddingTop = UDim.new(0, UI.INSET),
		PaddingBottom = UDim.new(0, UI.INSET),
		PaddingLeft = UDim.new(0, UI.INSET),
		-- reserve the scrollbar here: VerticalScrollBarInset shrinks the window when the bar shows
		-- but (1, 0)-wide children still size against the whole frame and slide under the bar
		PaddingRight = UDim.new(0, UI.INSET + s.ScrollBarThickness),
		Parent = s,
	})
	return s
end

------------------------------------------------------------------ HUD column + toasts
local hud: Frame? = nil
local function hudColumn(): Frame
	if hud and hud.Parent then
		return hud
	end
	local gui = UI.screen("KitHud", 5)
	local col = UI.make("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(140, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.list(col, 10)
	hud = col
	return col
end

function UI.hudButton(text: string, onClick: () -> ()): TextButton
	return UI.button(hudColumn(), text, onClick)
end

local toasts: Frame? = nil
function UI.toast(text: string, kind: ("good" | "bad" | "info")?)
	local t = UI.theme()
	if not toasts or not toasts.Parent then
		local gui = UI.screen("KitToasts", 20)
		toasts = UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 64),
			Size = UDim2.fromOffset(420, 300),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		local l = UI.list(toasts :: Frame, 6)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local color = if kind == "good" then t.good elseif kind == "bad" then t.bad else t.panel
	local f = UI.panel(toasts :: Frame, UDim2.fromOffset(400, 48), nil, { BackgroundColor3 = color })
	local label = UI.text(f, text, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	if kind == "good" or kind == "bad" then
		label.TextColor3 = t.bg
	end
	task.delay(3, function()
		local fade = TweenInfo.new(0.3)
		TweenService:Create(f, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		task.wait(0.35)
		f:Destroy()
	end)
end

------------------------------------------------------------------ modal
-- returns the scrolling body to fill, and a close function
function UI.modal(title: string, width: number?, height: number?): (ScrollingFrame, () -> ())
	local t = UI.theme()
	local gui = UI.screen("KitModal_" .. title, 10)
	local shade = UI.make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local box = UI.panel(gui, UDim2.fromOffset(width or 520, height or 460), UDim2.fromScale(0.5, 0.5), { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = t.bg })
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(width or 520, height or 460), Parent = box })
	box.Size = UDim2.new(0.92, 0, 0.8, 0)
	UI.text(box, title, { TextSize = 28, Size = UDim2.new(1, -56, 0, 40) })
	local function close()
		gui:Destroy()
	end
	UI.button(box, "X", close, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -44, 0, -2), TextSize = 22 })
	shade.Activated:Connect(close)
	local body = UI.scroll(box, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50) })
	UI.list(body, 10)
	return body, close
end

return UI
