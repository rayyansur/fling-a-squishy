# kit: shared runtime for every game

Plumbing every game needs and that is easy to get subtly wrong: saves, purchases, remotes,
store UI. It's part of the pipeline (same in every game, like `build/` and `tools/`): improve it
in the template, then copy it into games. Game logic never goes here.

The build puts `kit/ReplicatedStorage/Kit` → `ReplicatedStorage.Kit` and
`kit/ServerScriptService/Kit` → `ServerScriptService.Kit`. The template's `Server` and `Client`
entry scripts start it. `kit/tests/*.test.luau` run in the cloud crash test with the game's own.

| Module | Side | What |
|---|---|---|
| `Kit.Data` | server | session-locked saves: `onLoaded`, `get`, `update`, `saveNow`, `changed`. Config: `Config.Data` |
| `Kit.Shop` | server | passes + products: `onPass`, `onProduct`, `owns`, `prompt`, `passivePrompt` |
| `Kit.Leaderboard` | server | all-time top lists on OrderedDataStores: `board(name, opts)` → `:set(player, value)`, `:top()`, `:onUpdate(fn)` |
| `Kit.Net` | both | validated, rate-limited remotes: `on`/`handle`/`fire`/`fireAll` (server), `send`/`call`/`listen` (client) |
| `Kit.Odds` | both | `roll(weights)` on the server, `percentages`/`format` to show odds |
| `Kit.Products` | both | catalog lookups: `list(kind)`, `get`, `id`, `passAttribute(key)` |
| `Kit.UI` | client | themed builders: `screen`, `panel`, `text`, `button`, `list`, `scroll` (inset so outlines never clip), `modal`, `toast`, `hudButton`, `bindAttribute`. Theme: `Config.Theme` |
| `Kit.StoreUI` | client | the store screen + purchase toasts; `setOdds(key, weights, label)` for random items |
| `Kit.Catalog` | both | **generated** from `game/monetization.json` + `game/monetization.lock.json` |
| `Kit.Icon` | client | the game's own images in GUIs: `set(label, name)`, `new(name, props)`, `has`, `content` |
| `Kit.Images` | both | **generated** from `art/images/*.png` (+ optional `.json` sprite rects, avoid them) + `art/images.lock.json` |

## Icons and images (`Kit.Icon`)
No emoji in the UI: every icon is a picture in the game's style. Draw them as tiny Blender
scenes in `art/icons/<group>.py` (`@icon("coin")` + `def coin(bpy, kit)`, the same kit as
`art/models`), then `<blender python> tools/icon_build.py` renders them (outlined, transparent)
and writes one `art/images/<name>.png` per icon (no sprite sheets: rect crops are wrong on some
real phones and consoles). Look at `out/icons/_contact.png` before
committing. CI uploads changed PNGs and writes `art/images.lock.json`; the build turns that into
`Kit.Images`. Any other PNG in `art/images/` (a logo, a banner) works the same, by file name.
```lua
local Icon = require(ReplicatedStorage.Kit.Icon)
Icon.new("coin", { Size = UDim2.fromOffset(40, 40), Parent = card })
Icon.set(someImageLabel, "star")
```
Until CI has uploaded an icon, it shows nothing (`Icon.has(name)` is false), like pink
placeholders for models.

## Saves (`Kit.Data`)
```lua
-- Config.luau
Config.Data = { store = "PlayerData_v1", defaults = { Coins = 0, Pets = {} }, mirror = { "Coins" }, leaderstats = { "Coins" } }
-- server module
Data.onLoaded(function(player, data) ... end)
Data.update(player, function(data) data.Coins += 10 end)   -- mirrors "Coins" to player:GetAttribute("Coins")
```
- New keys added to `defaults` later are filled in for existing players on load.
- Always read with `Data.get(player)` / write with `Data.update`; don't hold on to nested tables
  across yields (a product grant replaces them).
- A load that fails or stays locked kicks the player with a "nothing was lost" message; it never
  hands out a blank save. Changing `store` wipes everyone: only on purpose.
- Studio workbench (unpublished): saves live in memory for the session.

## Passes + products (`Kit.Shop`)
Declare items in `game/monetization.json` (keys are lower_snake_case, 2-4 of each per GUIDELINES):
```json
{
  "passes":   { "vip": { "name": "VIP", "description": "+20% coins forever", "price": 199, "icon": "art/icons/vip.png" } },
  "products": { "coins_500": { "name": "Bag of Coins", "description": "500 coins", "price": 49 } }
}
```
```lua
Shop.onPass("vip", function(player) ... end)                          -- join (if owned) + purchase
Shop.onProduct("coins_500", function(player, data) data.Coins += 500 end) -- runs inside the save
if Shop.owns(player, "vip") then ... end
Shop.passivePrompt(player, "vip")  -- the one unprompted offer per session; refused in the first 2 min
```
- CI (`tools/roblox_cloud.py sync-products`) creates/updates the items in the test universe on
  every push and commits their ids; the live release does the same for the live universe.
  `icon` is optional (512×512 PNG; passes show it on the game page).
- Items with no id in the current universe (the Studio workbench) are granted free in Studio, so
  every purchase path can be playtested. Outside Studio they can't be bought until synced.
- Paid random items: roll with `Odds.roll(weights)` and show the same weights in the store with
  `StoreUI.setOdds(key, weights, label)`.
- A game with its own store screen calls `StoreUI.start({ hudButton = false, toast = false })`,
  lists items with `Products.list(kind)`, buys with `Net.send("Kit.Buy", key)`, reads ownership
  from the `Pass_<key>` player attribute and listens to `Kit.Purchased` for its own toast.

## Remotes (`Kit.Net`)
```lua
Net.on("Plant", { args = { "string", "int" }, rate = 4 }, function(player, seed, slot) ... end)
Net.send("Plant", "carrot", 3)   -- client
```
Arg types are `typeof` names plus `int` (there is no `any`, and every declared arg is required:
send a mixed or optional value as a string); numbers must be finite; strings ≤ `maxString` (100).
Bad or too-fast calls are dropped. The server still checks game rules (cost, distance, cooldown).
