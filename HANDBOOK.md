# Handbook: making catchy Roblox games with this pipeline

`CLAUDE.md` says *what* to do and `GUIDELINES.md` holds Rayyan's rules; both win over this file.
This file is the experience behind them, written for any game: what makes a game catchy
(sections 0-3), how Rayyan works (4), and the Roblox, Studio, Lune, Blender and CI traps that
cost us time (5-13).

**Read it before starting a game or a feedback round. Add to it** (section 14) when a round
teaches something new.

---

## 0. A new game, start to finish (the fast path)

Build these in from the first PR and most feedback rounds disappear.

**Day 0: setup (one message to Rayyan)**
1. Ask the art style once if the idea doesn't say it (2-3 concrete directions).
2. Send him `NEW_GAME.md` (repo, secret, variable, test place). Build locally while he does it.
3. Write `DESIGN.md`: core loop, first 3 minutes, short/mid/long goals, max players, map, models,
   UI screens, monetization, risks. Keep it current: the next session reads it.

**First PR: the playable slice**
- One `Shared/Theme` used by every GUI and the kit; picture icons, never emoji (sections 1, 8).
- One plot per player in a shared server, with names, if the game is social (section 2).
- A core action that feels good on its own: real input, sound, animation (sections 1, 2).
- The first three minutes teach the loop **and the first purchase**, then show what's next.
- A Studio-only `DevGrant` remote so a solo playtest can reach late-game features (section 6).
- Generous pacing (section 3). Clean map edges, no clutter, nothing floating (section 10).

**Second PR: reasons to come back**
- Daily and weekly quests, a 7-day login reward, codes, all-time leaderboards (`Kit.Leaderboard`).
- Music that fits the setting and mood, plus ambience.
- Something to chase after the last upgrade: rebirth, a collection index, titles.
- Co-op that pays fairly, if the game has co-op.

**Third PR: monetization and polish**
- 2-4 passes and 2-4 products in `game/monetization.json` (GUIDELINES), a store with icons, one
  milestone offer per session, odds shown on random items.
- Game page art from the real game (section 11): an icon and 3 thumbnails in `marketing/`.

**Going live:** section 12. Never publish live yourself.

---

## 1. What makes a game catchy

Every rule here came from Rayyan's feedback or from how Roblox ranks games. Build them in by
default and check them in every Studio pass.

### The first three minutes
- Roblox ranks on players who leave within 60 s and 180 s (section 12). Spawn → the core action →
  a reward, within seconds. Nothing to read first.
- **Teach through the HUD in simple games**: a stat line that says what to do next, a glowing
  blueprint, a pulsing main button, a progress bar to the next goal, reward counts on buttons.
  A step-by-step tutorial is only for deeper loops (management, crafting): a short step machine
  that points at things in the world, covers the loop once and the **first purchase**, then
  rewards the player for finishing.
- Explain each system in-game the first time it matters (a toast, a label on the thing). A
  mechanic nobody explains reads as clutter and gets cut.
- Start slow and generous. Players should get help (a first helper, an auto-collector) before
  they feel overwhelmed.

### A loop that feels good
- **No core action is "just press E".** It's either a small minigame with real input travel, or a
  repeated action with anticipation, impact and sound (both in section 2).
- **Every run pays.** Let the action's own result decide the reward; put optional skill on top
  that adds to it and never blocks it. Fiddly hitboxes on fast-moving things feel janky.
- **Less waiting.** Standing on the start spot for a moment starts the next run (a disc fills
  under you); a repeat needs no button.
- **Never an error for "full".** Overflow goes to an Inventory (place or sell later), with a toast
  saying where it went. Only past the Inventory's cap does it auto-sell, again with a toast.
- Destructive actions use **hold** prompts (`HoldDuration` ≈ 0.8 s), short range, away from busy
  spots.
- **A living world:** NPC walkers, players' friends as NPCs, traffic, keepers behind counters,
  silly physical moments. Collectibles wander and make a quiet silly noise now and then (one
  sound + its own pitch per species, ≥ 2.5 s apart, short range). Anything that should move and
  doesn't is a bug: watch NPCs for a full minute.

### Always something to chase
- **Progression the player can't find doesn't exist.** Upgrades, rebirth and the index each get a
  HUD button, a "!" badge when something's ready, and an always-visible progress pill.
- **Everything visibly unlockable:** new rooms, floors and decor appear in the world the moment
  they're bought.
- **Absurd escalation:** rarer = HUGE (a top rarity ~6× a common), extra heads, glow, sparkles;
  zones that get sillier as you go; numbers that climb into the trillions and beyond (format up
  to decillions, never print `1e+20`).
- **Pull-and-reveal:** few identical mystery containers in the world, the payoff in a dramatic
  full-screen scene with "1 in N" odds (section 2).
- **Reasons to return:** dailies, a weekly, a 7-day reward, codes, all-time leaderboards, and new
  things to buy and choose between.
- **Social from the start:** a shared server, one named plot per player, co-op, leaderboards.
- Things spawned to collect despawn on a timer, commonest first (~1 min), so an area never fills
  with commons nobody wants.

### How it looks: UI
- **One Theme** (font, palette, corner radii, outline) on every panel, toast, billboard, minigame
  and kit modal. Rounded, chunky, friendly.
- **For a kids' game, the big-sim look:** saturated candy fills with a top shine, near-black
  outlines, white outlined text, LuckiestGuy titles and big numbers, big labelled menu buttons,
  money + the main stat huge in the bottom-left, panels with a glossy coloured header band, a
  red X, and a dark body with white cards.
- **HUD colours contrast with the world, never match it.** Anything floating over the map gets a
  saturated fill, white text and a dark text outline. **One colour per menu button**, repeated in
  that panel's header, so kids find things by colour. World billboards (name tags, plot signs)
  get a meaning colour: rarity, the plot's colour, gold for money. Judge it in a capture against
  the brightest ground in the game.
- Prefer an evergreen palette over a holiday one. "Very saturated" means intensity, not hue: keep
  the setting's own palette and turn it up; don't swap in off-theme neons.
- **One thing at the top of the screen at rest.** A tracker read at a glance (coloured segments,
  the player's head) beats a chip of numbers. Event timers and extra detail show only while they
  matter. Signs for empty plots show only up close (short `MaxDistance`).
- **Pictures, never emoji.** No gimmicky labels, decorative arrows or generic icons. Every icon,
  item, sound and word belongs to the game's world.
- Every card or panel that can be empty says what to do next in plain words, with a themed picture.
- Put the HUD menu where chat and the mobile thumbstick aren't (a bottom-left grid works). A
  left-middle column sits under the chat window's input bar: clicking the top button opens chat.

### How it looks: the world
- **Fewer, bigger, intentional props.** Would removing a prop make the shot worse? If not, remove
  it. Props never overlap each other, walls or walkways.
- **Generous space.** Avatars are ~4 studs wide and the camera is third-person: aisles ≥ 5 studs,
  wide roads, walkways that meet the buildings they serve.
- Close every map edge with invisible walls plus a believable end (buildings, a turn), never a
  void. Outside surfaces stop at walls; nothing exterior shows through a floor. **The gaps between
  buildings count as edges:** a 3-5 stud alley is wide enough for an avatar to reach the back of
  the block and fall. Scan a row at body height for open x-ranges between facades and fill each
  with an invisible wall (tag it so a test can count them).
- Every landmark has a purpose and a finished look (stairs, railings, lights, a sign, NPCs using it).
- **A themed zone is themed by what fills it, not by a name arch.** Per zone: one bold floor
  colour with a fine two-tone checker (section 7), solid walls with a coloured lip, a few chunky
  scattered props and one or two landmarks, something overhead, and neighbours that contrast.
  Nothing hides the view down a corridor.
- **When he sends a reference image, copy its construction**, not just its ideas, and put your
  capture next to it at the same camera angle before calling it done.
- Big floors are mid-tone, never white or pale (section 7); bright colours go on things you look
  at. For a saturated kids' look, ColorCorrection Saturation ≈ +0.35.
- No always-on particles on characters, even for paid perks. Use a name tag or a short burst.

### How it sounds
- Music fits the **setting and mood** (a cozy city at dusk = chill lo-fi), never a cultural
  stereotype of the theme. Same for sounds and fonts.
- Music sits well under the effects (music group 0.12, SFX 0.6). A shuffled short playlist, a
  looped ambience bed, a settings toggle. A silent game feels unfinished.

### Cut what doesn't pull its weight
Once the core loop is fun, Rayyan cuts whole systems. Remove the **whole** thing (checklist in
section 2) and replace stats or boards that showed it instead of leaving blanks.

### Reference games
When he sends a hit game and says "copy it", copy the *genre conventions* (layout, button styles,
an index with silhouettes, a featured shop card), never names, art or characters. Monetization
still follows GUIDELINES. Leave out the dark patterns (crossed-out "was" prices, fake countdowns)
and say so in the report.

---

## 2. Patterns that worked (reuse the pattern, not the code)

### Structure
- **Data-driven tuning:** `Shared/Config` (pacing, prices, save defaults, theme) and a
  `Shared/Upgrades` list (id, price, requirement, effect). The server applies it, the client
  shows it, and the cloud tests check the maths with plain tables (the crash test has no players).
- **One `Shared/Theme`:** palette, one font, three corner radii, one outline, pill buttons, a
  `Theme.tag()` helper for world billboards. Point `Config.Theme` at it so the kit matches.
- **One plot per player:** build one plot in the map, clone it N times, assign each player the
  free plot nearest the hub. Per-plot services are ModuleScripts cloned per plot and required
  with `setmetatable({ Plot = plot }, { __index = sharedServices })`; shared services (data,
  money) run once. Remotes act on "the plot this player owns". Budget plot × player count up front.
- **A hub between plots:** the spawn, stalls that open shop panels, leaderboards on a wall,
  signposts. A "go to hub / go home" button in the menu.
- **Co-op roles:** owner / member / visitor. A member's earnings go to the owner's wallet (no
  split); their own plot closes, saved, and reopens when they leave or are kicked. Invites
  expire. Friends joining via a game invite carry `LaunchData` and join directly.
- **Unlockables in the world:** models for unbought upgrades wait in ServerStorage. Placeholders
  that block a space are tagged with the upgrade that removes them.
- **Moving things without network traffic:** the server writes the motion once as attributes
  (a path or seed, a start time on `workspace:GetServerTimeNow()`, a speed) and every machine
  computes the same position from one Shared function. Use it for NPC routes, traffic, wander
  loops and player rides. The server can still check distances against the computed position.

### Core actions
- **Minigames per action.** Kinds that worked: full mouse strokes between two marks, circling a
  ring, aiming at targets (accuracy × time), key rhythm, timed stop. To feel fair: count only
  full travel, a short cooldown between presses, a server-issued **token** per task checked on
  finish, a cancel path, generous targets early on.
- **A repeated action that feels good** (hammering, mining, clicking):
  - a slow wind-up, a short hang, then an accelerating strike that **visibly lands** (measure the
    tool's contact point against the target in Studio);
  - on contact: a 3D impact sound with ±6% pitch, sparks, a flash, the target dipping and
    springing back, a small camera kick for your own hits only;
  - a reward chime that climbs in pitch with the streak (capped);
  - run the impact on each client from a shared beat (`T0 + k × period` on server time) so
    picture and sound line up; the server's event carries only the reward;
  - other players' hits are quieter, short range, no effects past ~90 studs.
- **A ride or launch:** `rideAt(kind, length, t)` in a Shared module; the server stores start
  time, kind and path. A good "rocket" feel is a 0.3-0.4 s quadratic launch into a long ease-out
  `1-(1-u)^2.6`. Obstacles come from one deterministic layout function shared by map, server,
  client and tests, with a clear middle lane. Hits **slow, never stop** (never shorten the coast
  time without shrinking the distance, or the rider speeds up). The way back looks physical: a
  tumble along the same path, limbs flopped through the joints' `Transform`.
- **A catch that takes almost no effort:** where the ride stops picks the pool, how deep adds
  luck, pickups along the route add more. The server rolls from **its own copy of the path**
  (at 200-500 studs/s it sees the rider tens of studs late, so tight distance checks refuse real
  pickups). **Save the catch before any scene plays.** Hold the player in a "landing" phase
  until the client says the scene is done, with a 30 s server timeout. Show earned luck on the
  HUD only once it's above ×1.00.
- **Cleaning a surface (powerwash-style).** Thin invisible "skin" parts lie just above each
  flat surface, each a grid of 0.5-stud cells holding a thickness; the client paints an
  `EditableImage` mask per skin near the camera. The client paints its own strokes at once and
  sends point batches; the server re-checks each point against **its own** HumanoidRootPart
  (zone, on-skin, reach, line of sight for sprays) and sends the true cells back for points it
  drops. What sells it: each object (a driveway, a bench) finishes at ~97% with a flash, its name
  and a ding that climbs a semitone per quick follow-up, a "find the last bit" outline at ~85%,
  and bright art painted underneath to reveal.
  - Every in-between thickness must look clearly different from untouched: a "thin" layer at
    85% alpha read as no progress at all; ~50% shows the ground through.
  - Test orientation with an **off-centre** stroke: a walk down a skin's middle hides a mirror.

### Collecting
- **Mystery container + reveal scene** (eggs, crates, gifts):
  - The world copy is one generic model with **no contents**. Roll on the server when it's
    opened, so nobody can read the instance tree to pick a winner.
  - The scene: dark shade, rotating light bars behind a ViewportFrame, the container shaking
    harder each time (more shakes for rarer), a colour "tell" one shake before the end for the
    upper rarities, then a swell, a white flash and a loud crack. Show rarity, name, modifier
    and **"1 in N" counting up from 1**. Click closes; overlapping scenes queue.
  - **Don't spoil it:** hide the item in the world, "new in your Index" news and any
    server-wide "X got a LEGENDARY" banner until the scene is over.
  - Skippable only for things already owned, never the first of each kind.
  - Pop text in with a `UIScale`, not `TextTransparency`.
- **Rolled traits** (Golden, Big, Rainbow): roll on the player's action, store on the item's
  record and in the save as an optional field (drop unknown values on load). Apply in place:
  recolour, then `Model:ScaleTo` (keeps welds). Mirror as an attribute so clients add particles
  and tag text. Multiply income and sell value through one helper. Show the odds.
- **A new kind of record** (a container among items) lacks the old fields. Grep every consumer
  of them first; a nil rarity lookup broke carrying.
- **Stacked parts** (extra heads) with accessories: move only what sits on the head to the top
  head. Things held or worn on the body stay.

### Progression and shops
- **Upgrades + rebirth that stay fair:** coins can be bought with Robux, so coin upgrades only
  touch the economy (income, discounts, capacity) and reset on rebirth. Anything that gives an
  edge against other players costs a **rebirth-only currency** and is permanent, which makes
  every rebirth feel worth it. Rebirth panel: requirement progress bar, a "You get" grid, what
  resets and what stays, the button visible without scrolling.
- **Shop items that boost a stat** (sleds, pets, tools): price each to its progression stage
  (base × growth^(stage-1)). Apply the boost where the stat is *used*. Every number the player
  compares to a threshold shows the boosted value. Save owned + equipped, survive rebirths, fall
  back to the starter on a bad save. Draw other players with their equipped item.
- **A pass that sells something also bought with coins:** keep the coin price (GUIDELINES).
  Grant from `Shop.onPass` (it runs on every join), once: if the save already owns it, do
  nothing. Put the Robux button on the item's card as well as in the Passes tab.
- **A progress track across levels:** a clipped HUD strip, one segment per zone, headshot
  markers per player, a flag at the player's reach; ease the scroll to keep the player centred.
- **Quests:** 3 dailies (reset 00:00 UTC) and 1 weekly (Monday), dealt from pools in `Config`.
  Progress hooks into the same events as earnings. A panel plus a toast on completion.
- **A set to curate:** the player buys items, then picks which are "on" in a few slots. It turns
  a flat shop list into choices.
- **Placeable furniture (decorate mode):** catalog + grid rules in one Shared module that the
  server, the client ghost and the map build all read. Templates are built at map time with an
  invisible footprint part as PrimaryPart. The client only previews (snap, green/red); the
  server re-checks every spot: zone and aisles, `GetPartBoundsInBox` against the map (skip
  people, invisible triggers and the furniture folder), other pieces, and every seat's walk-up
  path. Re-check all of it after any expansion is bought and send pieces in the way back to the
  tray. Furniture that adds seats uses the map's seat tag and attributes so the NPC code needs
  no changes. Exclude the furniture folder from wall raycasts too, or a re-checked painting
  blocks itself.
- **Placing mode shows the player's own plot.** If the pieces are sold somewhere else (a hub
  stall), "buy, then place" fails silently: the camera is in the street. Enter with a
  Scriptable overhead camera over their plot, hide what's above it (`LocalTransparencyModifier`
  on parts higher than the walls), pan with WASD/drag, zoom with wheel/pinch, turn with Q/E, sink
  the movement keys with `ContextActionService`, and send the character home.
- **Seating as tables + chairs (restaurant sims):** a chair is a seat only when it touches a
  table's side (≥ 1 cell of overlap), up to the table's capacity, and it turns to face the table
  by itself. The walk-up spot is the middle of the cell behind the chair. Use **one** margin for
  "this route is clear" and "this piece blocks a route", under half a cell, or a row of chairs
  blocks itself. On a re-check, destroy the moved or removed builds first (stale seats block
  routes) and don't count a table's own chairs against it. Moving a table carries its chairs
  (rotate their offsets; any that no longer fit go to the tray); putting it away takes them too.
- **Built-in upgrades → placeable pieces:** take them off the shop, delete their models at map
  time (after any file that reads them, before plots are cloned), and give old saves the same
  pieces once (a flag on the save), auto-arranged near where they stood by searching the grid
  outward from a hint with the server's own check.
- **Once players can place seating, every seat is placeable** ("you can't pick up the stools
  that come with the store"). Make the built-in ones catalog pieces too: fixed counters become
  hidden "tables" in the same module (a rect, a capacity, how far the seat tucks in), every save
  gets the starter pieces once, an unowned plot shows them so it never looks empty, and the
  server refuses removing the last seat (the tutorial's first guest needs one).
- **A bare table looks like seating to a player.** After placing one, go straight on to placing
  a chair and say why ("nobody sits at a table without one").
- **Free hooks:** codes, a 7-day reward (toast a few seconds after join), a group bonus (leave
  `Config.GroupId = 0` until Rayyan gives one).
- **Monetization that fit:** 2x cash, a VIP area, speed perks, a cosmetic name tag; products for
  cash scaled to progress, a temporary boost, a random box with odds shown. **Count
  `game/monetization.json` before promising a Robux item.** At the cap, build it as a coin item
  and tell him swapping a pass is his call.

### Replacing rebirth (or any reset) for longevity
More late content at rising levels (each tier pricier and paying more), a level cap, and a
small permanent bonus per level. Keep the XP curve: levels are worked out from saved XP, so
changing it re-levels every save. Keep the old saves' fields that still pay out.

### Removing a feature
Sweep every place it lives, then add a test that it's gone:
- server and client modules and the list that loads them; remotes; HUD buttons and keybinds;
- map parts, prompts and attributes; save fields, leaderstats, boards, analytics;
- quests, badges, perks and upgrades that mention it; sounds, config blocks, tests, DESIGN.md;
- any pass or product it sold (deleting it from `game/monetization.json` takes it off sale);
- every client reader of a state field the server stops sending (`#nil` throws).

Then grep each identifier and read the type checker's new "unused local" notes.

---

## 3. Pacing and economy

- **Slower is easier to fix than faster.** Ship generous, tighten if he says it's too easy.
- **Exponential progressions:** before picking constants, write a 50-line Python sim of an
  optimal player and print the hour each tier is reached. A 25-tier ramp that worked: tier 10
  at ~2 h, tier 25 at ~27 h (power ×8.85 per tier, boosts ×9.2 per level, costs ×12, income ×8).
  Keep any numbers Rayyan gave exactly (validate at boot) and ramp smoothly from them.
- **Management loops:** customers wait ~2 minutes and arrive every ~15 s at the start (faster
  with popularity, never below a few seconds). Timed tasks last well past the time they take.
- **The first helper costs about one tutorial's worth of earnings** and is there from the first
  tier.
- Level curves like L^1.5 felt fine. Finishing a tutorial grants level 2.
- **A finite resource (snow that doesn't regrow):** the sim must read how much there is from the
  map build (write per-zone stats to `out/` in the validate script), and a test pins those totals
  so a map edit can't silently break prices. A "cells per unit" constant lets you keep an old
  price ladder when the resource's grain changes. Helpers that consume the same resource compete
  with the player: tune their pay share in the sim too.

---

## 4. Working with Rayyan

### A round
- He sends an idea once, then **feedback rounds**: one long lowercase message mixing bugs, feel
  notes and features, often 10-20 items. Every clause is a work item. Make a checklist before
  coding and tick it off in the report.
- He playtests the **test place** with a real mouse (sometimes a phone). He judges look and
  feel; "fun" is his call.
- He won't answer many questions mid-round. Pick sensible defaults and list them in the report.
- He does the account-side steps (repo, secrets, test place, key, uploads, live publish). Ask in
  **one** message with exact clicks, and keep building while you wait. For a command Claude
  can't run (e.g. `gh repo create`), hand him `! <command>`.
- He may be playtesting when a change ships; his running playtest keeps the old build. Tell him.

### Planning
- Split big feedback into themed PRs (bug/feel pass, UI look, the big feature), quick fixes
  first. Each gets its own Studio pass and CI run.
- Structural changes (one shop → one per player, a wider map) get their own PR and a re-check of
  every view.
- Stack dependent branches; after the base merges,
  `git rebase --onto origin/main <old-base> <branch>`.
- Write tests with the feature. CI catches what screenshots miss: missing tags, moved positions.

### Reading him
- Typos are normal. "do that and republish pls, then lets continue with the next" = fix it, hand
  him the publish link, move to the next item on your last list. "is everything good?" = check
  CI, the test place and the live game, and report.
- When something "isn't working", find out what he's looking at before changing code (a stale
  Studio window, an old playtest).
- Long clauses that pile up negatives are easy to misread. Work out **which area each clause is
  about**, rebuild the sentence without the negatives, check it against his reference images,
  and name your reading in the report.

### Turned down (don't propose again without a new reason)
- Offline earnings. Co-op member cuts. Particle effects on players as perks.
- A step-by-step tutorial in a simple collecting game.
- A self-modelled Roblox avatar or invented mascot in art (section 11).

### The report (end of every round)
One short message in plain words, mapping each of his items to what you did:
- what shipped, grouped by PR with links, and 1-3 screenshots;
- **"changes you didn't ask for"**: defaults you chose, anything removed;
- "please playtest": what only a real player can judge;
- what you couldn't test and why; what's waiting on him.

Never say something is fixed without seeing it fixed.

---

## 5. Roblox engine traps

### Text and UI
- **`TextWrapped = false` turns `TextScaled` off** when a place file loads. Signs look fine in
  the build and tiny on the server. Use both true (`B.surface{ wrap = true }`).
- **Glyphs:** FredokaOne has no `✕` (use "X"); some newer emoji (🫓, 🪙) don't render. Write
  "coins", not 🪙. Check in a capture.
- A SurfaceGui's `Front` is the part's local −Z. Wrong face = mirrored or upside-down sign.
  SurfaceGui text vanishes at grazing angles and long distances: check boards straight-on.
- **A UIStroke draws outside its frame and a ScrollingFrame clips at its edges**, so cards at
  (0, 0) lose their outline. Use `UI.scroll` (it pads the body and reserves the scrollbar).
  Don't use `VerticalScrollBarInset = ScrollBar`. Size cells by scale against the inset width
  (`UDim2.new(1/7, -9, …)`), not fixed pixels.
- **`ClipsDescendants` clips to the rectangle, not the `UICorner`.** Square children poke out of
  rounded frames. Use a rounded `CanvasGroup`, or round the children. An `ImageLabel` with a
  `UICorner` is already round (headshots).
- **Screen UIScale:** fit fixed-size modals with their own UIScale
  (`min(1, screen / (size × screenScale))`), refit on change, and make the HUD fit a 1250 × 700
  virtual screen. A phone in landscape is ~390 px tall.
- Keep ≥ 12 px between a button and its card's edge. Don't blanket-replace UDim2 offsets.
- Hide a name tag while a more important billboard shows over the same head.
- **A row of BillboardGuis** (one per pad, stall, plot): size them in studs (`UDim2.fromScale`)
  with scale-sized labels, so far ones shrink. Pixel-sized boards stack into a wall from a
  distance. Hide the one for the thing the player is already in.

### Prompts
- **A ProximityPrompt trigger is validated against the prompt's SERVER position.** If clients
  animate a model locally while the server copy stays put, presses are silently dropped. Move
  the server copy too (10 Hz is plenty), or use client-side prompts + a validated remote.
- **Test prompts through the real path:** in a playtest, from the Client,
  `prompt:InputHoldBegin()` + `InputHoldEnd()`, away from where the object spawned. Dev
  shortcuts that call the handler skip the engine's check; simulated E presses don't reach
  prompts.

### Replication and Luau
- **Attributes replicate one at a time.** If a client starts on attribute X, write X last on the
  server (clear it first) and have the client re-read missing values each frame.
- **Multiple returns spread into calls:** `math.min(a, f())` where `f` returns two values is
  `math.min(a, s, extra)`. Wrap it, `(f())`.
- Remote names must be unique across RemoteEvents and RemoteFunctions, or server start-up breaks.
- **A "you can't pass" wall must stand before any zone trigger** that acts on players on foot.
- **One place, two modes (lobby + reserved-server runs):** keep each mode's server and client
  modules in their own folders, started by the entry script. The crash test starts every module
  that's a direct child of a server Script, so loose mode modules would boot in the wrong mode.
- `TeleportOptions.ReservedServerAccessCode` is flagged deprecated in the type defs but is still
  how a party enters a `ReserveServer` code. Assign it through an `any` local:
  `(opts :: any).X = v` as a statement is an "ambiguous syntax" error.
- **Shared client code must not listen for a remote only the other mode creates:** the client
  `WaitForChild`s it for 15 s, then errors, and everything after it boots late. Guard the
  listen with the mode. The startup print (`[Client] <mode> ready at N s`) shows this at once.
- **Client prediction plus server patches needs acks in the same stream.** A server patch (or
  snapshot, or correction) holds the true cells *without* the client's strokes still in flight,
  so applying it undoes them, and skipping your own echoes means they never come back. Number
  each batch, have the server ack it **as a record in the same ordered remote** as the patches,
  and after any patch paint your unacked strokes again *inside the patch box only*. Send
  corrections after the batch's ack, merged into one box per surface. A capped or partial result
  that already holds the batch must be preceded by its ack.
- **Rate-limit movement-made actions by movement:** a token bucket filled by server-seen
  distance (and idle time), +25% and a burst for lag spikes, not by remote calls per second.

### Input
- The default camera "processes" arrows and WASD. Sink them with ContextActionService while a
  minigame is open, and force `MouseBehavior = Default` for mouse minigames.

### Characters and NPCs
- `Players:CreateHumanoidModelFromDescription` gives real avatars for NPCs. Use catalog ids
  verified to load, and the default R15 animations (walk 913402848, idle 507766666,
  sit 2506281703, wave 507770239). Check outfits up close: hair through hats, items that fail.
- **Joints are AnimationConstraints on new avatars, Motor6Ds on old.** Both have `Transform`.
  Pose by writing `Transform` every frame in `RunService.Stepped`, finding joints with
  `IsA("AnimationConstraint") or IsA("Motor6D")`. A Motor6D-only check silently poses nothing.
  `C0`/`C1` on an AnimationConstraint are read-only. Confirm the pose in a capture.
- Anchored, script-posed NPCs: convert to Motor6D + Weld, anchor the root, set
  `Humanoid.EvaluateStateMachine = false`.
- **The character spawns before async saves load.** Anything dressed onto it from the save
  (held tool, backpack, hat) must also be applied when the data arrives, not only on
  `CharacterAdded`.
- **The Animator replicates late.** Don't require it at `ChildAdded`; retry loading tracks, sweep
  for untracked NPCs every second, and pcall each NPC's per-frame step.
- **Seeded wander loops with keep-out circles:** check every stretch including last → first,
  and redraw the whole loop from the same seeded `Random` until it's clean. Test many seeds.
- **Staff/NPC job queues sorted by deadline starve long orders.** A big order with a long timer
  (catering: 5 dishes, 8 min) sits behind every short one until it's too late to make. Sort on a
  start-by time instead: `deadline − work per item still to do`.

### Physics and world
- Decorative props: `CanCollide = false` plus one plain invisible collider where players bump.
- Nothing important below `workspace.FallenPartsDestroyHeight`.
- **A `WorldPivot` set in the map build doesn't survive publishing.** Give the model an
  invisible `Root` part at the pivot as its `PrimaryPart`.

### Audio
- Pick from Roblox's licensed library with `search_asset`. For SFX, add "Pro Sound Effects" to
  the query and keep only creators `ProSoundEffects` or `APMOfficial` (APM "stings" make good
  comedy noises).
- **Check each id loads:** in a Client playtest, make a `Sound`, wait for `IsLoaded`, read
  `TimeLength` (0 = unusable). `ContentProvider:PreloadAsync` reports success for bad ids.
- Scale extra music layers relative to the music SoundGroup.
- Unparented `Sound`s never load in Edit, even good ids: only a playtest can check them.
  User-uploaded audio may only play in its owner's games; stick to the two library creators.

### Data
- `TextService:FilterStringAsync` fails in Studio: allow raw text only when `IsStudio()`. Live
  servers refuse when the filter errors, and reject results containing `#`.
- OrderedDataStores only work in a published place. Values only go up (`Kit.Leaderboard`).
- Changing a DataStore name wipes everyone. Add save fields through `Config.Data` defaults.
- Product grants run on a **copy** of the save (`Kit.Shop`): mutate only the `data` passed in.

### Budgets
- **EditableImage / EditableMesh** in a published game need the owner ID-verified and Game
  Settings → Security → **Allow Mesh / Image APIs** on. Creation can fail on low-memory devices:
  always have a fallback look, keep a cap on live images, and `Destroy()` the ones you drop.
- A **Decal on a Top face** shows image pixel (0, 0) at the part's **+X, +Z** corner. Grid code
  that starts at −X, −Z must write pixels turned 180°.
- Lights hit the 200 cap long before parts hit 15,000. Drop spotlights on signs first; use Neon,
  `LightInfluence = 0` SurfaceGuis and emissive glass.

---

## 6. Studio MCP playbook

### The window
- `list_roblox_studios` every session (the id changes when Studio restarts). Use the workbench
  `Build.rbxlx` that Rayyan has open. **Never open Studio windows or places yourself**, and never
  use menus to save, publish or close. No workbench open: ask him for **File → Recent → Build**.
- **Sync only into the workbench.** Never into an original `.rbxlx` or a window of the live place.
- A window of a published place doesn't refresh when CI publishes. If his is stale, he closes it
  **without saving** (saving would overwrite the real game) and reopens from Roblox.
- **He playtests in the workbench too.** A sync made before CI's art/icon upload shows pink
  placeholders and blank icons, and he'll report them as bugs ("it's just purple boxes", "new
  items don't have icons"). Re-sync after pulling the upload bot commit before handing over,
  and when a report sounds like that, check the workbench's build first.
- **Sync:** `tools/studio_prepare.sh` → clear old `chunk_*.json` in
  `~/code/roblox-pipeline-builds/studio/` → copy `out/studio/*` there → `execute_luau` (Edit)
  with `tools/studio/sync_snippet.luau`. If it's refused ("not in the Assistant HTTP
  allowlist"), copy `out/Game.rbxlx` to `~/code/roblox-pipeline-builds/Preview.rbxlx` and ask him
  to open it.
- Delete the workbench's own Baseplate, Bloom, ColorGrading and test objects before judging looks.
- The sync skips properties left at their default, and can't set `Lighting.Technology`.

### Captures
- `screen_capture` with a camera position and look-at, **one at a time** (parallel captures hang
  or return the wrong shot). In Play, setting the client's `CurrentCamera` doesn't move it.
- Capture every `pipeline.json` view, each sign straight-on, and each new space at eye height
  (~5 studs). Overview shots hide floating and clipping.
- **A single capture hangs** while `get_studio_state` answers: Studio isn't drawing (display
  asleep, window hidden) and client `RenderStepped` code has stopped too. Stop after two tries,
  verify through instance state, and say screenshots were skipped.
- Point lights don't render reliably in edit-mode captures. Raise `Lighting.Ambient` and
  `ExposureCompensation` for the shot, then resync.
- **Blank or half-drawn model right after a sync:** usually still loading. Wait and recapture.
- **Pink model** = art not uploaded yet (`PendingArt`). An all-pink screen = the camera is
  inside a placeholder. Neither is a bug.
- **A timed moment:** a capture lands ~2-3 s after the call. Trigger from `execute_luau`, wait
  (target − 2.5 s) in the same call, then capture. A dev command that replays the scene alone
  makes retries free.

### execute_luau
- Needs `datamodel_type` (Edit, Server, Client). **It gets its own copy of every ModuleScript:**
  `require` runs the module fresh, so the game's live state isn't there. Read the instance tree
  and attributes, and change state the way a player would: fire the game's remotes from the
  Client, including the dev remote. `_G` persists between calls in one datamodel.
- **`DevGrant`:** a remote declared only when `RunService:IsStudio()` that skips ahead (cash, a
  milestone, tutorial done, "force the next roll"). It's how one solo playtest sees everything.
- **It resets cutscene cameras** when a call returns. Hold a cutscene camera every frame
  (RenderStepped sets `CameraType = Scriptable` and the `CFrame`). To film one, trigger it as a
  player would and return from the snippet before it starts.
- **Running client module code without clicks** (Studio not drawing, mouse input dead): clone
  the ModuleScript, parent the clone next to the original (`script.Parent.X` requires resolve),
  `require` it with a stub ctx, call its functions, then destroy the clone and any GUI it made.
  It catches runtime errors, not visuals.

### Driving a playtest
- **Checklist:** start → wait `playtestSeconds` → `get_console_output` (any error or warning from
  game scripts is a bug) → check state in Server and Client → watch moving things for a minute →
  stop.
- **Clicking UI:** `user_mouse_input` with an `instance_path`; name buttons by id so paths are
  stable. For coordinates, ask the Client for the target's centre in viewport space:
  `b.AbsolutePosition + b.AbsoluteSize / 2 + GuiService:GetGuiInset()`. Clicking a HUD button
  while a panel is open hits the shade and just closes it.
- **Mouse input may not arrive** (Studio unfocused): the tool reports success, nothing happens.
  Check with a capture; else verify through remotes and say which screen went unseen.
- **Moving the character:** `character_navigation` fails inside fenced plots. Teleport with
  `Character:PivotTo` (Server), walk with `Humanoid:Move(dir)` in a loop (Client), steer with
  `user_keyboard_input`. Minigames need real input and time-boxed tasks expire.
- **UI audit** (every pass that touches UI): open the HUD alone, then every panel and tab, and
  run `return require(game.ReplicatedStorage.PipelineUIAudit)()` (Client). It reports CLIPPED,
  OFFSCREEN, TIGHT and TEXT, in the real window and an emulated 700 px-tall phone. Fix until
  every screen says `ok`.
- **Studio can't test:** more than one player, real purchases, the text filter,
  OrderedDataStores. Say so in the PR and the report.

---

## 7. Map building (Lune) traps

### Lune
- Deserialized parts have no `.Position` ("missing default value"): use `.CFrame.Position`. Same
  for `ClockTime`, `WorldPivot` and other unset properties.
- **Set an Attachment's `.CFrame`, never `.Position`:** Lune writes `.Position` under a name
  Roblox ignores, so the attachment loads at (0, 0, 0) (tools held from the wrist, effects at the
  part's centre).
- No `GetBoundingBox` or `GetPivot`: write a rotation-aware `bounds()` from the CFrame vectors ×
  size, and read a model's `PrimaryPart.CFrame` (or a known part's) instead of its pivot.
- `GetDescendants()` snapshots hold destroyed instances. Collect first, destroy after.
- Keep `B.partCount` honest when you clone or remove (the budget check reads it).
- Scripts run in `NN_` order and later ones may move earlier work. Then attributes holding
  **world positions** must move with their parts, and anything that belongs to a building but
  sits outside its model moves into it before cloning. Prefer fixing the original script.
- Shared ground that needs a hole per plot (stairwell, basement) is carved per plot.
- `luau.load` environments must be **flat tables**: the import fast path ignores `__index`, so
  `game`/`require` come back nil. Lune has no `Random`; a test runner needs its own small LCG.
- **A map script can `require` a Shared game module** by relative path
  (`require("../src/ReplicatedStorage/Shared/X")`) if the module touches no Roblox globals at
  load: keep its data plain numbers and tables, with `Vector3`/`CFrame` only inside functions.
- **Porting an old `.rbxlx`:** export to `.rbxm`, load with `B.import`, fix the export's bugs in
  a script (parts at y+1,000,000, offset attributes, strays at the origin).

### Floors and colour
- **Big pale floors wash out to white**, and pure white ground is blinding. Use SmoothPlastic or
  Snow in mid tones, a step darker and more saturated than you want them to read, with a clear
  second tone. Keep Ice and bright colours for features.
- **Surface textures** (checker, planks): a transparent PNG in `art/images/` tints any part
  colour. In the map script, read `art/images.lock.json`, check the sha256 like `build/main.luau`
  does, and add `Texture`s only when the id is there. It exists only after the "Upload art" bot
  commit, so push before judging it in Studio.
- **Z-fighting:** flat parts that overlap at the same height flicker, and so do side faces in
  one plane (a base slab as wide as the walls on it). Offset heights slightly (0.2 / 0.23), make
  under-layers thinner, keep inner pieces inside. Rings of box segments always overlap on the
  inside of the curve. Scan before shipping: flat parts near the ground with equal tops and
  overlapping footprints.
- **Paint under something** (art revealed under snow, markings on a road): thin slabs between
  0.005 and 0.045 above the surface, no collide/query/touch, and a build check that fails on any
  two coplanar paint pieces that overlap (it catches the centre of radial patterns).

### Construction
- **Floating/clipping scan** (offline, before Studio): union-find parts that touch, flag clusters
  touching neither floor nor wall, and parts whose bottom sits below their floor.
- Modular wall pieces must reach the corners: check length × count against the span between the
  corner pieces' *faces*.
- Build signs and furniture as clear, simple shapes (an A-frame, a framed board on posts).

---

## 8. Art (Blender) traps

### Models
- **The bar:** anything players collect or see up close gets round shapes with 14-16 sides and
  soft shading; so do its wearables. Scenery can stay chunky. Buildings need real construction:
  planks or logs, a footing, a roof with thickness and overhang, windows on every side, a framed
  door. Check proportions against the 5-stud player.
- **Look at all four preview views** (`out/art/<name>.png`). Side and back come from −X; render
  +X too if something lives there. Small details hide inside bigger shapes.
- **FBX axes:** Blender (x, y, z) → Roblox (−x, z, y). A model facing Blender +Y needs a 180°
  spin when placed. Pivot = bottom-centre of the bounding box.
- Nothing below Z = 0, or the whole model sits too high once placed.
- Blender's cylinder and cone put their **first vertex on +Y**: a 3- or 4-sided one (a prism
  roof, a square slab) comes out turned. Rotate parts about their own centre (build at the
  origin, rotate, then set `location`), or rotated pieces swing away from where you meant.
- **One mesh name = one colour in Roblox** (same-named objects merge into one MeshPart). Name
  meshes per colour, and check multi-colour models in Studio: the Blender preview hides this.
- **`Fabric` darkens colours a lot.** Use `SmoothPlastic` for small cloth; `Wood`, `Slate` or
  `WoodPlanks` on big surfaces.
- Flat pieces sharing a face plane render black where they overlap: make the front one ≥ 0.1
  stud thicker. Bent tubes: sweep one ring along the path, not short cylinders. Bezier tubes
  overshoot corners: use `smooth=False` and draw corners as arcs.
- **Triangles:** ≤ 10k per model. A torus costs thousands; use ridges in a lathe profile. Spend
  them where they show (manifest `parts[].tris`). A shared builder for a family of models (food
  trays, plates) can add a DECIMATE modifier to the detail objects when the total is over budget.
- Keep script-used parts (a seat, a pot's water) as named parts, and test they exist. Don't
  attach ground decor to a model players carry.
- **Wearables:** judge them on the body (a throwaway model that imports the body's and the
  accessories' `build()`; delete it, its `.fbx` and its manifest entry before committing). Keep
  each to one place (head *or* body *or* hand) so they combine without clipping.
- Rebuild **all** models before committing; a preview render may leave a stale FBX.
- Code that swaps parts for models keeps the old parts until the lock has the model.

### UI icons
- `art/icons/*.py` → `tools/icon_build.py <names>` (Blender venv) → check
  `out/icons/_contact.png` → `Kit.Icon`. Icon names live in data from day one.
- When converting from emoji, grep for `.icon` inside `format()`: it prints the icon's name.
- **One image per icon, never sprite sheets.** `ImageRectOffset`/`ImageRectSize` crops are
  wrong on some real devices (Android phones, PS5) although Studio draws them right: Rayyan saw
  "everything has the wrong thing" on the test place while every Studio capture looked fine.
  Studio can't show it, so don't use rect crops for anything that matters.
- A new or changed icon shows its emoji fallback until CI uploads it (give every icon one). Push,
  wait for the "Upload art" bot commit, pull, rebuild, then judge icons in Studio. The first
  upload of a whole set takes a while (batches of 20); if it stops part way, the next push
  finishes it.
- Shoot dishes and bowls from ~25° above so the rim and the inside both show.

---

## 9. Machine, git and CI

### Rayyan's Mac
- `export PATH="$HOME/.local/bin:$PATH"` before `tools/check.sh` (Lune, luau-lsp) **and
  `tools/studio_prepare.sh`**: without it the prepare step fails silently and the Studio sync
  quietly reloads the previous build. Check the "synced build <id>" number changed.
- Blender: `~/.local/share/blender-venv/bin/python tools/art_build.py <name>` (same for
  `icon_build.py`).
- Node is under nvm. If a hook blocks an old Node: `nvm install <major>
  --reinstall-packages-from=<old>`, then `nvm alias default <major>`.
- macOS bash is 3.2 (no `mapfile`, no associative arrays). zsh doesn't word-split `$VAR`: use
  arrays.
- Foreground `sleep` is blocked. Watch CI with a `run_in_background` until-loop around
  `gh run view`.
- Scripted find-and-replace: anchor on text that appears once (for a module's final `return`,
  the last occurrence).

### Git and GitHub
- GraphQL and raw Actions logs are blocked. Use REST:
  - PR: `gh api repos/<repo>/pulls -f title=… -f head=<branch> -f base=main -F body=@body.md`
  - merge: `gh api -X PUT repos/<repo>/pulls/<n>/merge -f merge_method=squash -f
    commit_message="…"`. **Always pass `commit_message`**, or the squash inherits `[skip ci]`
    from bot commits and main's CI never publishes the test place.
  - CI errors: `gh api repos/<repo>/check-runs/<job id>/annotations` (job ids from
    `gh run view <id> --json jobs`).
- Branch from fresh main: `git fetch origin && git checkout -b idea/x origin/main`.
- In game repos `origin` = the game and `template` = `rayyansur/roblox-pipeline`. Never push a
  game's branch to the template. Check `git branch -vv` once: `main` must track `origin/main`.
- Template work happens in a `git worktree` off `origin/main`; never commit the main tree's
  local files.

### CI
- **Bot commits:** CI commits the art, image and monetization lock files as `[skip ci]` commits
  on your branch. `git pull` before building again or the build uses stale ids. A branch whose
  head is a bot commit gets no PR run: the push run before it and main's run after the merge
  cover it. Delete a merged branch only after main's run starts.
- **A PR that adds art fails its first PR run** ("image X has no uploaded id", "Y is a
  placeholder"): that run doesn't upload; the push run does, in parallel. Wait for the push run's
  lock commit, pull, push again: the next PR run is green. Only those two messages are expected.
- A "check failed at: Syntax-check the crash-test script" annotation on a green job is noise.
  Judge by the job's conclusion.
- **Errors:**
  - `401 Invalid API Key`: the repo secret is wrong or expired. Only Rayyan can fix it.
  - `403`: a scope is missing or the experience isn't on the key. The key needs
    universe-places (Write), Luau execution sessions, assets, game-pass and developer-product
    (Read + Write), for every experience.
  - `409 Server is busy` on publish: CI retries. If it keeps failing, the place is open in a
    Studio window (Team Create); it only clears when that window closes.
- No `roblox.testPlaceId`: CI skips the cloud steps. Don't push a new game's `idea/**` branches
  before its secret exists (the art upload dies without the key).
- **The crash test** runs on the published version in a real server: every module requires,
  every Server module starts, then `tests/cloud/*.test.luau`. It is the only place those run.
  - **Place Scripts don't run there** (it's a script-execution server). Only ModuleScripts that
    are direct children of a server Script get started, by the harness. Keep boot logic in such
    a module (`Boot.start()`), never in the Script's own body, or nothing boots in the test.
  - That server has a `PrivateServerId` and `PrivateServerOwnerId == 0`, so it looks like a
    reserved server. A lobby + runs place boots as a run there: test the lobby's layout from its
    map template, not from `workspace`.
  - Wait for the game to be ready (a `ready` flag, then `t.waitFor(fn, 20)`), don't race it.
  - Find things by tag or attribute and loop over every plot. Pinned positions break on any move.
  - **Don't pin content counts** (`#BrothOrder == 6`, "9 props in storage"): count the data
    tables. Every content round otherwise breaks an unrelated test.
  - Tests that sample a curve keep **both** samples past the boundary. Run the same loop in Lune
    locally first.

---

## 10. Visual QA checklist (every Studio pass)

1. Workbench leftovers removed.
2. Every `pipeline.json` view captured, plus eye-level shots of each new or changed space.
3. Nothing floating, sunk into a floor, clipping or flickering.
4. Exterior materials stop at walls.
5. Every sign readable straight-on, the right way round, text scaled, no missing glyphs.
6. Walkways ≥ 5 studs, doors reachable, the core loop's path clear.
7. Map edges closed and believable.
8. Decorative collisions off; colliders where you should bump.
9. No permanent particles on players. Lights within budget.
10. HUD readable against the brightest ground; one thing at the top of the screen at rest.
11. Playtest: console clean; everything that should move does for a full minute; the core loop
    works end-to-end with real input; the Theme is on every screen.
12. UI audit `ok` on the HUD and every panel and tab, at window and phone size (section 6).
13. Clutter check: would removing a prop make the shot worse? If not, remove it.

---

## 11. Game page art (icon + thumbnails)

- **Use the real game.** What reads as "AI generated": a character that isn't a Roblox avatar,
  drawn-on faces, waxy shading, heavy blur and glow. **Never model an avatar yourself.** Build
  the real one in Studio from catalog items (`HumanoidDescription`; ids from
  `catalog.roblox.com/v1/search/items/details?Keyword=…&CreatorName=Roblox`).
  `CreateHumanoidModelFromDescription` works in Edit.
- **Study current top games first** (no key needed):
  `apis.roblox.com/explore-api/v1/get-sorts?sessionId=<uuid>`,
  `apis.roblox.com/search-api/omni-search?searchQuery=<genre>&sessionId=<uuid>`,
  `thumbnails.roblox.com/v1/games/icons?universeIds=…&size=512x512`. Keep references out of the
  repo (`~/code/roblox-pipeline-builds/refs/`).
- **The look that works for kids' games:** loud sim-game style, not realism. Bright flat light,
  a sky gradient with light streaks, a white sticker outline round the characters, a glow behind
  the hero, a rainbow per-letter one-word title, one big number, a red curved arrow and "!!".
- **Logo:** LuckiestGuy and FredokaOne ship inside Studio
  (`RobloxStudio.app/Contents/Resources/content/fonts`). Set letters one by one with their own
  tilt, a cream inner line, a thick dark outline and a hard shadow.
- Icons: no text, cropped tight on the subject so it reads at ~150 px. Thumbnails: 16:9, nothing
  vital at the bottom edge.

### Staging in Studio
- Press Play, dress the scene through the game's real remotes. Clear NPCs and name tags **right
  before every capture**: they can be real friends' avatars and usernames.
- Pose anchored avatars with forward kinematics: `child.CFrame = parent.CFrame *
  parentAtt.CFrame * rotation * childAtt.CFrame:Inverse()`. Accessories move with the head.
  Destroy every Constraint and Attachment after posing, and the Humanoid's `Animator` (its rig
  overlay draws joint lines over the capture).
- **Faces:** the default head has no face and ignores `HumanoidDescription.Face`. Hide it and
  add a `Part` with a `SpecialMesh` (`MeshType.Head`) and a face `Decal`
  (`rbxasset://textures/face.png`, or `InsertService:LoadAsset(faceId)` for a classic one).
- Camera: `FieldOfView` ~38 (30 for a green-screen key). Hide HUDs with `ScreenGui.Enabled` and
  `SetCoreGuiEnabled`. `ExposureCompensation` about −1.3 indoors, −0.75 outdoors.
- A dusk or night map tints a green-screen avatar purple: give the stage plain daylight and save
  and restore the game's Lighting around it. A sync replaces Lighting's children, so never reuse
  saved references across one. Edit mode can't show the game's lighting technology either: a
  night street captures near-black, so shoot real-game thumbnails in daylight.

### Blender scene + real avatar
- Import the game's own `art/models` `build()` functions into the scene. Render scenery and
  characters as two transparent layers (`visible_camera = False` keeps the soft shadows).
- Capture the Studio avatar in front of a pure-green part square to the camera and key it in
  Pillow (alpha from green − max(red, blue), despill, shrink the matte 1 px). Export each shot's
  camera in Roblox coordinates and line up the model's projected box (`WorldToViewportPoint`)
  with its box in the render.
- A standing avatar: a hidden blocky stand-in with the same pose marks where it goes (and casts
  its shadow); the Studio camera uses the shot's position and vertical FOV
  (`2·atan(sensor_h / 2 / lens)`) but aims at the avatar's middle. What it holds renders as a
  third layer composited over the keyed avatar. Keep pose names the same in both scripts.
- Stroke fat arrows by stamping discs along the curve.
- Worked examples: `steal-the-snowmen/marketing/` (a rider on a sled),
  `slurp-lab/marketing/` (standing chefs holding bowls, a seated guest).

---

## 12. Going live

### Claude's part
1. Rayyan creates the live experience (publish a baseplate from Studio) and sends the place and
   universe ids.
2. Put them in `pipeline.json` (`roblox.livePlaceId`, `roblox.liveUniverseId`) in a small PR;
   merge on green.
3. **Before he publishes,** `list_roblox_studios`: if the live place is open, ask him to close
   that window first (it causes endless 409s).
4. Send him `https://github.com/<repo>/actions/workflows/pipeline.yml` with the clicks: **Run
   workflow** → `main` → tick **publish_live** → green button. Claude never clicks it.
5. When he says it's done, check the jobs
   (`gh api repos/<repo>/actions/runs/<id>/jobs --jq '.jobs[] | [.name, .conclusion] | @tsv'`),
   pull the "products: live ids" bot commit, and tell him.
6. Every later fix that should reach players needs another `publish_live` run: say so with the
   link. Running servers keep the old version until they close.

### Rayyan's part (send as one numbered list, paste-ready)
1. Join the live game while it's still **Private**. Earn something, leave, rejoin, check it saved.
2. Game page: title, genre, description (below).
3. Upload the icon and 3+ thumbnails from `marketing/`. Turn on **thumbnail personalization**.
4. Optional: a short gameplay video (it lifts Home plays a lot).
5. The **questionnaire**. Declare any paid random item.
6. Check every pass and product is on sale at the intended price.
7. Set the game **Public**.
8. Later: the 16+ gate steps (below).

### The game page description
- Flashy and scannable, under 1,000 characters: an emoji welcome line, a one-line pitch, **HOW
  TO PLAY** and **FEATURES** lists with one emoji per line, "👍 Like + ⭐ Favorite". A title
  emoji, and for updates a tag in front (`[NEW] …`). Read a few live ones first:
  `apis.roblox.com/universes/v1/places/<placeId>/universe`, then
  `games.roblox.com/v1/games?universeIds=<ids>`.
- **The text filter rejects whole descriptions without saying why.** Avoid anything that could
  read as innuendo, rows of all-caps code words, and joined emoji (👨‍🍳). Say "check the Codes
  menu" instead of listing codes. If it's refused, he saves the title alone, then the
  description in halves.
- Every line must be true of the game today.
- While a game is Private the public APIs return nothing for it. Ask Rayyan what he sees.

### What Roblox ranks on (researched 2026-11)
- Home recommendations rank on **first-play bounce** (leaving within 60 s / 180 s), play-through
  rate, **play days per user over 28 days**, playtime (capped at 60 min/day) and co-play with
  friends. Ads, search and friend traffic don't count.
- Only the default thumbnail = **no Home recommendations**. Thumbnail personalization raised
  play-through ~8.5%; gameplay video raised quality plays up to 47%.
- Fair spending inside progression helps. Unclear or unfair purchases hurt.
- **The 16+ gate:** a new game is shown only to age-checked 16+ users until it gets 250 plays
  from highly engaged users within 60 days (or an expedited review). Opening it to under-16s
  needs his verified account, 2-step verification, a Minimal-to-Moderate maturity rating, and
  Premium or a refundable fee. The first three minutes and the page art must be right
  **before** any ad spend.
- Targets: D1 retention ≥ 12% (median ~10%), sessions 12+ min (median ~10). Short daily goals,
  co-op and visible next goals move these most.
- Ship small updates every 2-4 weeks and big ones every 2-3 months.

---

## 13. Known limits of the pipeline

- No multiplayer testing before Rayyan's playtest (Studio MCP is solo; the crash test has no
  players). Keep multiplayer logic unit-testable (roles, wallet routing, plot assignment) and
  ask him to test with a friend.
- Published-only features (OrderedDataStores, the text filter, real purchases) are verified by
  Rayyan.
- Game page art is made by Claude and uploaded by Rayyan, like everything else on the page.
- Nobody but Rayyan can listen to music or judge "fun". Say what you chose and why.

---

## 14. Adding a lesson (and keeping this lean)

After a round, add what cost more than one try, or what Rayyan said that would apply to another
game. Rules:
- **Generic:** the trap, the symptom, the fix, in 1-3 lines. No quotes, dates, PR numbers or
  game names (a pointer to a worked example is fine). Game-only facts go in that game's
  `DESIGN.md`.
- **One home:** put it in the section it belongs to and link from elsewhere with "(section N)".
  Update or replace the existing line rather than adding a second one.
- **Delete what's dead:** when the tooling now prevents a trap, or a later lesson overrules an
  earlier one, remove the old line.
- Sections 0, 6 and 12 are referenced by number from `CLAUDE.md`. Keep those numbers.
