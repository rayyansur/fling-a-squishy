--!strict
-- Kit.Icon: show the game's own images (art/images/*.png, uploaded by CI) in GUIs.
--   Icon.set(label, "coin")          an ImageLabel/ImageButton shows the sprite "coin" (from any
--                                    sprite sheet) or the whole image named "coin"
--   Icon.new("coin", { Size = ..., Parent = ... })   a new transparent ImageLabel showing it
--   Icon.has("coin")                 true once that image is uploaded (Studio shows nothing before)
--   Icon.content("coin")             (image id, rect offset, rect size), e.g. for a Beam or a Decal
-- Sprite names are unique across sheets; an unknown name warns once and shows nothing.

local Images = require(script.Parent.Images)

local Icon = {}

type Found = { id: string, offset: Vector2, size: Vector2 }

local cache: { [string]: Found } = {}
local missing: { [string]: boolean } = {}
local warned: { [string]: boolean } = {}

local function find(name: string): Found?
	if cache[name] then
		return cache[name]
	elseif missing[name] then
		return nil
	end
	local found: Found? = nil
	local whole = Images[name]
	if whole and not whole.sprites then
		found = { id = whole.id, offset = Vector2.zero, size = Vector2.zero }
	else
		for _, img in Images do
			local r = img.sprites and img.sprites[name]
			if r then
				found = { id = img.id, offset = Vector2.new(r[1], r[2]), size = Vector2.new(r[3], r[4]) }
				break
			end
		end
	end
	if found then
		cache[name] = found
	else
		missing[name] = true
	end
	if not found and not warned[name] then
		warned[name] = true
		warn(("Kit.Icon: no image or sprite named %q (add it to art/images)"):format(name))
	end
	return found
end

function Icon.has(name: string): boolean
	local f = find(name)
	return f ~= nil and f.id ~= ""
end

function Icon.exists(name: string): boolean
	return find(name) ~= nil
end

function Icon.content(name: string): (string, Vector2, Vector2)
	local f = find(name)
	if not f then
		return "", Vector2.zero, Vector2.zero
	end
	return f.id, f.offset, f.size
end

function Icon.set(target: ImageLabel | ImageButton, name: string?)
	local label: any = target
	if not name or name == "" then
		label.Image = ""
		return
	end
	local id, offset, size = Icon.content(name)
	label.Image = id
	label.ImageRectOffset = offset
	label.ImageRectSize = size
	label:SetAttribute("Icon", name)
end

function Icon.new(name: string?, props: { [string]: any }?): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Icon"
	label.BackgroundTransparency = 1
	label.ScaleType = Enum.ScaleType.Fit
	label.Size = UDim2.fromOffset(32, 32)
	local parent = nil
	local any: any = label
	local given: { [string]: any } = props or {}
	for k, v in given do
		if k == "Parent" then
			parent = v
		else
			any[k] = v
		end
	end
	Icon.set(label, name)
	label.Parent = parent
	return label
end

return Icon
