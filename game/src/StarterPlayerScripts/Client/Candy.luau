--!strict
-- Candy UI builders (DESIGN 7.1): chunky lip buttons with press bounce, white panels with a
-- gradient header, pills, a toast stack, count-up numbers, flying coins, one modal at a time.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Icon = require(ReplicatedStorage.Kit.Icon)

local P, F = Theme.Palette, Theme.Fonts
local Candy = {}

Candy.BOUNCY = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Candy.QUICK = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Candy.POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local player = Players.LocalPlayer

function Candy.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	for _, c in (children or {}) :: { Instance } do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local make = Candy.make

function Candy.corner(parent: Instance, r: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 22), Parent = parent })
end

function Candy.stroke(parent: Instance, w: number?, color: Color3?)
	return make("UIStroke", { Thickness = w or Theme.Panel.stroke, Color = color or P.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function Candy.textStroke(label: Instance, w: number?)
	return make("UIStroke", { Thickness = w or 2, Color = P.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
end

function Candy.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = F.body,
		TextColor3 = P.ink,
		TextScaled = true,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	for k, v in (props or {}) :: { [string]: any } do
		(l :: any)[k] = v
	end
	return l
end

-- icon with emoji fallback while the sprite sheet isn't uploaded
function Candy.icon(parent: Instance, name: string, props: { [string]: any }?): GuiObject
	local fallback = Config.UI.Fallback[name]
	if Icon.has(name) or not fallback then
		local img = Icon.new(name, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent })
		for k, v in (props or {}) :: { [string]: any } do
			-- text-only props belong to the emoji fallback label
			if string.sub(k, 1, 4) ~= "Text" and k ~= "Font" then
				(img :: any)[k] = v
			end
		end
		return img
	end
	local l = Candy.label(parent, fallback, { Font = Enum.Font.GothamBold, TextColor3 = P.white })
	for k, v in (props or {}) :: { [string]: any } do
		(l :: any)[k] = v
	end
	return l
end

-- put an icon at the left of a button's face and shift its label right
function Candy.buttonIcon(b: Button, name: string)
	local h = b.face.AbsoluteSize.Y > 0 and b.face.AbsoluteSize.Y or 60
	local holder = make("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(0.7, 0, 0.7, 0), Parent = b.face })
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = holder })
	Candy.icon(holder, name)
	-- the icon is 0.7 h wide from x = 8: start the label past it (0.55 h let it cover the first letter)
	b.label.Position = UDim2.new(0, h * 0.7 + 12, 0, 5)
	b.label.Size = UDim2.new(1, -(h * 0.7 + 20), 1, -10)
end

-- screen gui with the DESIGN 7 UIScale (base 1920x1080, clamp 0.6-1.2)
function Candy.screen(name: string, order: number?): ScreenGui
	local gui = make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		DisplayOrder = order or 0,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = make("UIScale", { Parent = gui })
	local function fit()
		local cam = workspace.CurrentCamera
		local v = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
		local base = Config.UI.BaseResolution
		local s = math.min(v.X / base[1], v.Y / base[2])
		-- never smaller than what fits a 1250x700 phone landscape
		s = math.clamp(s, Config.UI.ScaleMin, Config.UI.ScaleMax)
		if Candy.isTouch() then
			s *= Config.UI.TouchBoost
		end
		s = math.min(s, v.X / 1250, v.Y / 700)
		scale.Scale = math.max(s, 0.45)
	end
	fit()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return gui
end

function Candy.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

export type Button = {
	frame: Frame,
	face: TextButton,
	label: TextLabel,
	setKind: (string) -> (),
	setText: (string) -> (),
	setEnabled: (boolean) -> (),
}

-- chunky candy button: a darker lip under the face; press drops onto the lip and bounces back
function Candy.button(parent: Instance, text: string, kind: string, size: UDim2, onClick: (() -> ())?, props: { [string]: any }?): Button
	local lip = Theme.Lip
	local frame = make("Frame", { BackgroundTransparency = 1, Size = size, Parent = parent })
	for k, v in (props or {}) :: { [string]: any } do
		(frame :: any)[k] = v
	end
	local scale = make("UIScale", { Parent = frame })
	local under = make("Frame", { Name = "Lip", BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -lip), Position = UDim2.fromOffset(0, lip), Parent = frame })
	local face = make("TextButton", { Name = "Face", AutoButtonColor = false, BorderSizePixel = 0, Text = "", Size = UDim2.new(1, 0, 1, -lip), Parent = frame })
	local radius = math.min(22, math.floor((size.Y.Offset > 0 and size.Y.Offset or 60) / 2))
	Candy.corner(under, radius)
	Candy.corner(face, radius)
	Candy.stroke(face, 3)
	Candy.stroke(under, 3)
	local label = Candy.label(face, text, { Font = F.header, TextColor3 = P.white, Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5) })
	Candy.textStroke(label, 2)
	local enabled = true
	local function setKind(k: string)
		local c = Theme.Buttons[k] or Theme.Buttons.primary
		face.BackgroundColor3 = c[1]
		under.BackgroundColor3 = c[2]
	end
	setKind(kind)
	face.MouseButton1Down:Connect(function()
		if not enabled then
			return
		end
		TweenService:Create(face, Candy.QUICK, { Position = UDim2.fromOffset(0, lip) }):Play()
		TweenService:Create(scale, Candy.QUICK, { Scale = 0.95 }):Play()
	end)
	local function release()
		TweenService:Create(face, Candy.QUICK, { Position = UDim2.fromOffset(0, 0) }):Play()
		local up = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 1.04 })
		up.Completed:Once(function()
			TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		end)
		up:Play()
	end
	face.MouseButton1Up:Connect(release)
	face.MouseLeave:Connect(function()
		face.Position = UDim2.fromOffset(0, 0)
		scale.Scale = 1
	end)
	face.Activated:Connect(function()
		if enabled and onClick then
			Candy.click()
			onClick()
		end
	end)
	return {
		frame = frame,
		face = face,
		label = label,
		setKind = setKind,
		setText = function(t: string)
			label.Text = t
		end,
		setEnabled = function(on: boolean)
			enabled = on
			if not on then
				setKind("disabled")
			end
		end,
	}
end

-- set by the Sound module
Candy.click = function() end

-- rounded pill (HUD stats)
function Candy.pill(parent: Instance, size: UDim2, color: Color3?, props: { [string]: any }?): Frame
	local f = make("Frame", { BackgroundColor3 = color or P.white, Size = size, BorderSizePixel = 0, Parent = parent })
	Candy.corner(f, math.floor(size.Y.Offset / 2))
	Candy.stroke(f, 3)
	for k, v in (props or {}) :: { [string]: any } do
		(f :: any)[k] = v
	end
	return f
end

-- count a label up to a value over 0.25 s
local counting: { [TextLabel]: { from: number, to: number, t0: number, fmt: (number) -> string } } = {}
function Candy.countTo(label: TextLabel, value: number, fmt: ((number) -> string)?)
	local cur = counting[label]
	local from = if cur then cur.to else value
	counting[label] = { from = from, to = value, t0 = os.clock(), fmt = fmt or Format.abbrev }
end
game:GetService("RunService").RenderStepped:Connect(function()
	local now = os.clock()
	for label, c in counting do
		local a = math.clamp((now - c.t0) / 0.25, 0, 1)
		label.Text = c.fmt(c.from + (c.to - c.from) * a)
		if a >= 1 then
			c.from = c.to
		end
	end
end)

-- one modal at a time (DESIGN 7.3): 920x640, header gradient, X / Esc / B closes
local modalGui: ScreenGui? = nil
local openModal: { close: () -> (), name: string }? = nil

function Candy.closeModal()
	if openModal then
		local m = openModal
		openModal = nil
		m.close()
	end
end

function Candy.modalOpen(): string?
	return openModal and openModal.name
end

export type Modal = { root: Frame, body: Frame, close: () -> (), title: TextLabel }

function Candy.modal(name: string, title: string, w: number?, h: number?, onClose: (() -> ())?): Modal
	Candy.closeModal()
	if not modalGui then
		modalGui = Candy.screen("CandyModals", 20)
	end
	local W, H = w or Config.UI.PanelSize[1], h or Config.UI.PanelSize[2]
	local root = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Theme.Panel.bg,
		BorderSizePixel = 0,
		Active = true, -- clicks on the panel's empty space must not reach the world (a throw)
		Parent = modalGui,
	})
	-- fit the modal to the screen on its own (HANDBOOK 5: modals on phones)
	local fit = make("UIScale", { Parent = root })
	local function refit()
		local cam = workspace.CurrentCamera
		local gui = modalGui :: ScreenGui
		local screenScale = (gui:FindFirstChildOfClass("UIScale") :: UIScale).Scale
		if cam then
			local v = cam.ViewportSize
			local s = math.min(1, (v.X - 24) / (W * screenScale), (v.Y - 60) / (H * screenScale))
			fit.Scale = 0.85 * s
			TweenService:Create(fit, Candy.BOUNCY, { Scale = s }):Play()
		end
	end
	refit()
	Candy.corner(root, Theme.Panel.corner)
	Candy.stroke(root, Theme.Panel.stroke)
	local header = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = P.white, BorderSizePixel = 0, Parent = root })
	Candy.corner(header, Theme.Panel.corner)
	make("UIGradient", { Color = ColorSequence.new(Theme.Panel.headerFrom, Theme.Panel.headerTo), Parent = header })
	-- square off the header's bottom corners
	local skirt = make("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BorderSizePixel = 0, BackgroundColor3 = P.white, Parent = header })
	make("UIGradient", { Color = ColorSequence.new(Theme.Panel.headerFrom, Theme.Panel.headerTo), Parent = skirt })
	local titleLabel = Candy.label(header, title, { Font = F.header, TextColor3 = P.white, Size = UDim2.new(1, -140, 0, 48), Position = UDim2.fromOffset(24, 12), TextXAlignment = Enum.TextXAlignment.Left })
	Candy.textStroke(titleLabel, 2)
	local body = make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Theme.Panel.padding, 72 + Theme.Panel.padding),
		Size = UDim2.new(1, -2 * Theme.Panel.padding, 1, -72 - 2 * Theme.Panel.padding),
		Parent = root,
	})
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		root:Destroy()
		if onClose then
			onClose()
		end
	end
	Candy.button(header, "X", "primary", UDim2.fromOffset(56, 56), function()
		Candy.closeModal()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8) })
	openModal = { close = close, name = name }
	return { root = root, body = body, close = function()
		if openModal and openModal.close == close then
			Candy.closeModal()
		else
			close()
		end
	end, title = titleLabel }
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if openModal and not (processed and input.KeyCode == Enum.KeyCode.Escape and GuiService.MenuIsOpen) then
			Candy.closeModal()
		end
	end
end)

-- scrolling body inset so card outlines never clip (HANDBOOK 5)
function Candy.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = P.grape,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8 + 12), Parent = s })
	for k, v in (props or {}) :: { [string]: any } do
		(s :: any)[k] = v
	end
	return s
end

-- tabs row; returns select(name)
function Candy.tabs(parent: Instance, names: { string }, onSelect: (string) -> ()): (string) -> ()
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Parent = parent })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), Parent = row })
	local buttons: { [string]: Button } = {}
	local function select(name: string)
		for n, b in buttons do
			b.setKind(if n == name then "primary" else "secondary")
		end
		onSelect(name)
	end
	for _, n in names do
		buttons[n] = Candy.button(row, n, "secondary", UDim2.fromOffset(180, 56), function()
			select(n)
		end)
	end
	return select
end

------------------------------------------------------------------ toasts (right edge, max 4)
local toastGui: ScreenGui? = nil
local toastList: Frame? = nil
function Candy.toast(text: string, color: Color3?)
	if not toastGui then
		toastGui = Candy.screen("CandyToasts", 15)
		toastList = make("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -24, 0.42, 0),
			Size = UDim2.fromOffset(420, 360),
			Parent = toastGui,
		})
		make("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastList })
	end
	local list = toastList :: Frame
	local kids = {}
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids >= Config.UI.ToastMax then
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	local card = Candy.pill(list, UDim2.fromOffset(400, 64), color or P.white)
	card.LayoutOrder = math.floor(os.clock() * 1000)
	local l = Candy.label(card, text, { Font = F.header, TextColor3 = if color then P.white else P.ink, Size = UDim2.new(1, -28, 1, -14), Position = UDim2.fromOffset(14, 7) })
	if color then
		Candy.textStroke(l, 2)
	end
	local s = make("UIScale", { Scale = 1.15, Parent = card })
	TweenService:Create(s, Candy.POP, { Scale = 1 }):Play()
	task.delay(Config.UI.ToastSeconds, function()
		if card.Parent then
			local t = TweenService:Create(s, TweenInfo.new(0.15), { Scale = 0 })
			t.Completed:Once(function()
				card:Destroy()
			end)
			t:Play()
		end
	end)
end

-- pulse a GuiObject's UIScale until stop() is called
function Candy.pulse(obj: GuiObject): () -> ()
	local s = obj:FindFirstChild("PulseScale") :: UIScale?
	if not s then
		s = make("UIScale", { Name = "PulseScale", Parent = obj })
	end
	local scale = s :: UIScale
	local tween = TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 })
	tween:Play()
	return function()
		tween:Cancel()
		scale.Scale = 1
	end
end

-- 3-8 coin icons fly from a screen point to a target GuiObject (pooled, max 30)
local flyGui: ScreenGui? = nil
local flying = 0
function Candy.flyCoins(from: Vector2, target: GuiObject, n: number)
	if not flyGui then
		local made = Candy.screen("CandyCoins", 30)
		made.IgnoreGuiInset = true
		flyGui = made
	end
	local gui = flyGui :: ScreenGui
	local scale = (gui:FindFirstChildOfClass("UIScale") :: UIScale).Scale
	local to = target.AbsolutePosition + target.AbsoluteSize / 2 + Vector2.new(0, GuiService:GetGuiInset().Y)
	for i = 1, math.clamp(n, 3, 8) do
		if flying >= Config.UI.CoinFlyMax then
			return
		end
		flying += 1
		local c = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui })
		Candy.icon(c, "coin")
		local jitter = Vector2.new(math.random(-60, 60), math.random(-60, 60))
		local p0 = (from + jitter) / scale
		c.Position = UDim2.fromOffset(p0.X, p0.Y)
		local p1 = to / scale
		local t = TweenService:Create(c, TweenInfo.new(0.45 + i * 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(p1.X, p1.Y) })
		t.Completed:Once(function()
			c:Destroy()
			flying -= 1
		end)
		t:Play()
	end
end

return Candy
