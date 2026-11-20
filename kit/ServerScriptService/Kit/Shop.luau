--!strict
-- Shop: game passes + developer products from game/monetization.json (ids per universe come
-- from CI, see Kit.Products). The game only says what each item does:
--
--   Shop.onPass("vip", function(player) ... end)            -- on join if owned, and on purchase
--   Shop.onProduct("coins_100", function(player, data) data.Coins += 100 end)
--   if Shop.owns(player, "vip") then ... end
--   Shop.passivePrompt(player, "vip")                       -- at most once per session, never on join
--
-- Clients open the store with Kit.StoreUI (or Net "Kit.Buy" with an item key). Product grants
-- run inside Data.update, the receipt id is recorded in the same save, and the save is written
-- before Roblox is told PurchaseGranted, so a product is never granted twice or lost.
-- Items with id 0 (not created in this universe) are granted for free in Studio only.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = ReplicatedStorage.Kit
local Products = require(Kit.Products)
local Net = require(Kit.Net)
local Data = require(script.Parent.Data)

local Shop = {}
Shop.PASSIVE_DELAY = 120 -- seconds after joining before a passive prompt is allowed

local passHandlers: { [string]: (Player) -> () } = {}
local productHandlers: { [string]: (Player, { [string]: any }) -> () } = {}
local owned: { [Player]: { [string]: boolean } } = {}
local joinedAt: { [Player]: number } = {}
local passivePrompted: { [Player]: boolean } = {}
local started = false

------------------------------------------------------------------ receipts (pure)
-- Grants a product into a session at most once per purchase id.
-- Returns "granted" (new grant, needs a save), "duplicate" (already granted) or "error", msg.
function Shop.applyReceipt(session: Data.Session, purchaseId: string, grant: ({ [string]: any }) -> ()): (string, string?)
	if table.find(session.receipts, purchaseId) then
		return "duplicate", nil
	end
	-- grant into a copy so a handler that errors halfway leaves the save untouched
	local draft = Data.copy(session.data)
	local ok, err = pcall(function()
		grant(draft)
	end)
	if not ok then
		return "error", tostring(err)
	end
	for k in session.data do
		if draft[k] == nil then
			session.data[k] = nil
		end
	end
	for k, v in draft do
		session.data[k] = v
	end
	table.insert(session.receipts, purchaseId)
	return "granted", nil
end

------------------------------------------------------------------ passes
local function setOwned(player: Player, key: string)
	local mine = owned[player]
	if not mine or mine[key] then
		return
	end
	mine[key] = true
	player:SetAttribute(Products.passAttribute(key), true)
	local h = passHandlers[key]
	if h then
		task.spawn(h, player)
	end
end

local function checkPasses(player: Player)
	owned[player] = owned[player] or {}
	for _, entry in Products.list("passes") do
		local id = Products.id("passes", entry.key)
		if id ~= 0 then
			for attempt = 1, 3 do
				local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
				if ok then
					if has then
						setOwned(player, entry.key)
					end
					break
				end
				task.wait(attempt)
			end
		end
	end
end

function Shop.owns(player: Player, key: string): boolean
	assert(Products.get("passes", key), "Shop.owns: no pass '" .. key .. "' in game/monetization.json")
	local mine = owned[player]
	return mine ~= nil and mine[key] == true
end

function Shop.onPass(key: string, fn: (Player) -> ())
	assert(Products.get("passes", key), "Shop.onPass: no pass '" .. key .. "' in game/monetization.json")
	passHandlers[key] = fn
	for p, mine in owned do
		if mine[key] then
			task.spawn(fn, p)
		end
	end
end

function Shop.onProduct(key: string, fn: (Player, { [string]: any }) -> ())
	assert(Products.get("products", key), "Shop.onProduct: no product '" .. key .. "' in game/monetization.json")
	productHandlers[key] = fn
end

------------------------------------------------------------------ prompts
local function grantFree(player: Player, kind: string, key: string)
	-- Studio only: items that don't exist in this universe yet are free so they can be tested
	print(("[Kit.Shop] Studio: granting %s '%s' to %s for free (id 0)"):format(kind, key, player.Name))
	if kind == "passes" then
		setOwned(player, key)
	else
		local session = Data.session(player)
		local h = productHandlers[key]
		if session and h then
			local result = Shop.applyReceipt(session, "studio-" .. key .. "-" .. os.clock(), function(data)
				h(player, data)
			end)
			if result == "granted" then
				Data.update(player, function() end) -- refresh mirrored attributes
			end
		end
	end
	Net.fire(player, "Kit.Purchased", kind, key)
end

-- returns false when the item can't be bought here (unknown key, or no id outside Studio)
function Shop.prompt(player: Player, key: string): boolean
	local kind: "passes" | "products" = if Products.get("passes", key) then "passes" else "products"
	if not Products.get(kind, key) then
		return false
	end
	if kind == "passes" and Shop.owns(player, key) then
		return false
	end
	local id = Products.id(kind, key)
	if id == 0 then
		if RunService:IsStudio() then
			grantFree(player, kind, key)
			return true
		end
		print(("[Kit.Shop] '%s' has no id in universe %s yet (CI creates it on the next push)"):format(key, Products.universe()))
		return false
	end
	if kind == "passes" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
	return true
end

-- The one unprompted purchase offer per session (GUIDELINES): never in the first
-- PASSIVE_DELAY seconds, never twice, never for a pass the player owns.
function Shop.passivePrompt(player: Player, key: string): boolean
	local joined = joinedAt[player]
	if not joined or passivePrompted[player] or os.clock() - joined < Shop.PASSIVE_DELAY then
		return false
	end
	if Products.get("passes", key) and Shop.owns(player, key) then
		return false
	end
	passivePrompted[player] = true
	return Shop.prompt(player, key)
end

------------------------------------------------------------------ start
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = Products.keyForId("products", receipt.ProductId)
	local h = key and productHandlers[key]
	if not key or not h then
		print(("[Kit.Shop] no handler for product %s; Roblox will retry later"):format(tostring(receipt.ProductId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.waitFor(player, 20)
	local session = Data.session(player)
	if not session or not session.alive then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local result, err = Shop.applyReceipt(session, receipt.PurchaseId, function(data)
		h(player, data)
	end)
	if result == "duplicate" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif result == "error" then
		print(("[Kit.Shop] grant for %s failed: %s"):format(key, tostring(err)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.update(player, function() end) -- refresh mirrored attributes + changed listeners
	if not Data.saveNow(player) then
		-- the grant + receipt stay in memory and go out with the next save; until then Roblox retries
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Net.fire(player, "Kit.Purchased", "products", key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.start()
	if started then
		return
	end
	started = true
	Net.declare({ "Kit.Purchased" })
	Net.on("Kit.Buy", { args = { "string" }, rate = 1, burst = 3, maxString = 64 }, function(player, key)
		Shop.prompt(player, key)
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = Products.keyForId("passes", passId)
		if purchased and key then
			setOwned(player, key)
			Net.fire(player, "Kit.Purchased", "passes", key)
		end
	end)
	local function joined(player: Player)
		joinedAt[player] = os.clock()
		checkPasses(player)
	end
	Players.PlayerAdded:Connect(joined)
	for _, p in Players:GetPlayers() do
		task.spawn(joined, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		owned[p], joinedAt[p], passivePrompted[p] = nil, nil, nil
	end)
end

return Shop
