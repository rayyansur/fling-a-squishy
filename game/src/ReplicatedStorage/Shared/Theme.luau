--!strict
-- One look for every GUI (DESIGN 7.1, 9.2): candy palette, FredokaOne headers, chunky buttons.
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local Theme = {}

Theme.Palette = {
	pink = hex("#FF4FA3"),
	sky = hex("#3EC5FF"),
	lime = hex("#7CF25A"),
	lemon = hex("#FFD23F"),
	grape = hex("#9B5CFF"),
	orange = hex("#FF8A3D"),
	taffy = hex("#FFB3D9"),
	cream = hex("#FFE3F1"),
	ink = hex("#2B1B4A"),
	white = hex("#FFFFFF"),
	blush = hex("#FF9EC7"),
}

-- button kinds: face colour + lip colour
Theme.Buttons = {
	primary = { hex("#FF4FA3"), hex("#C2286F") },
	secondary = { hex("#3EC5FF"), hex("#1E8FC2") },
	success = { hex("#7CF25A"), hex("#4DB52E") },
	disabled = { hex("#D9D4E6"), hex("#AFA8C2") },
	grape = { hex("#9B5CFF"), hex("#6B32C9") },
	lemon = { hex("#FFD23F"), hex("#D9A400") },
}

Theme.Fonts = {
	header = Enum.Font.FredokaOne,
	number = Enum.Font.GothamBlack,
	body = Enum.Font.GothamBold,
	small = Enum.Font.GothamMedium,
}

Theme.Panel = {
	bg = hex("#FFFFFF"),
	corner = 22,
	stroke = 4,
	padding = 18,
	headerFrom = hex("#FF4FA3"),
	headerTo = hex("#9B5CFF"),
}

Theme.Lip = 4

-- Kit.UI theme (kit modals, store, toasts) in the same colours
Theme.Kit = {
	font = Enum.Font.FredokaOne,
	bg = hex("#FFFFFF"),
	panel = hex("#FFE3F1"),
	text = hex("#2B1B4A"),
	subtext = hex("#6E5C8F"),
	accent = hex("#FF4FA3"),
	accentText = hex("#FFFFFF"),
	good = hex("#7CF25A"),
	bad = hex("#FF5A5A"),
	corner = 22,
}

return Theme
