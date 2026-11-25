# DESIGN.md: Throw a Squishy

> Rayyan's spec, saved as the design brief (sections 1-17, verbatim). The template's `CLAUDE.md`
> is the runbook. Section 18 lists the builder's decisions where the spec is silent; keep it current.
>
> **Rule for the builder:** do not invent features, names, numbers, colors or flows that aren't here.
> If something truly isn't covered, pick the simplest option consistent with this spec, then list it
> under section 18 and in the PR description. Every tunable number lives in `Config` modules (section 13).

---

## 1. One-paragraph pitch

**Fling a Squishy** is a fast, bright throw-to-collect simulator in a candy world. Pull back your **Slingshot** and fling a blob of goo across **Squish Valley**. It splats, and a **squishy** pops out of the splat. Land on a wobbling **Jelly Pad** and the goo bounces even farther (up to 3 times). The farther the splat, the rarer the squishy, from Common Bao Buns in Gumdrop Meadow to Mythics at the Rainbow Rim. Squishies hop back to your **Shelf** and earn coins every second. Tap **SQUEEZE** for an instant coin burst from every squishy, then **merge** three identical squishies into a bigger Chonky one, and three Chonkies into a Mega one. Spend coins on better goo, stronger gloves and more shelf space, then **Re-Squish** (rebirth) for permanent boosts. Everything is fast: a fling every half second, short flights, instant feedback, big squash-and-stretch. The clip moment is a max-power fling that bounces BOING-BOING-BOING off three Jelly Pads into the Rainbow Rim, where a Mythic squishy bursts out under a rainbow beam.

- **Genre tag on Roblox:** Simulation
- **Max players per server:** 12
- **Target session:** 15–40 min. Return hooks: offline income, daily streak, scheduled Goo Rain, Squishydex, merge goals.
- **Platforms:** PC, mobile (first-class), console, tablet.
- **Art style:** **Bright candy low-poly**: flat-shaded low-poly meshes in saturated candy colors (section 9). Unlike the pastel games, this one is high-saturation and high-contrast.
- **Chat dependency:** none. No PvP.
- **Original IP only:** no real squishy brands, product names or character likenesses.

---

## 2. World layout ("Squish Valley")

Units are studs. +Z points out into the valley. The origin (0,0,0) is the center of the launch line at ground level.

### 2.1 Launch line and plots
- **Launch Terrace:** a raised candy-brick terrace 380 wide (X −190 to +190) and 60 deep (Z −60 to 0), color `#FFE3F1` with `#FF4FA3` trim.
- **12 Plots** along the terrace, evenly spaced from X = −176 to X = +176 (32 apart), at Z = −30. Each plot is 28 × 28 and contains:
  - The **Shelf**: a tiered candy display shelf (3 tiers, curved) at the back of the plot. Its slot count grows with upgrades (section 4.6). Squishies sit in slots and gently wobble.
  - The **Slingshot**: a giant Y-shaped candy-stick slingshot at the plot's front edge (Z = −2), facing +Z. The **Fling Point** is an Attachment at the pouch, height 6.
  - The **Squeeze Pad**: a 6 × 6 squishy-looking pad (it squashes when stepped on) in front of the shelf. Standing on it isn't required; it's decor that bounces when SQUEEZE is pressed.
  - The **Name Sign**: a BillboardGui above the shelf showing DisplayName, income/s and a "Re-Squish III" title if any.
- **Spawn:** a SpawnLocation at (0, 3, −52). After data loads, the player is teleported to their own Slingshot.

### 2.2 The valley and zones
The valley floor extends from Z = 0 to Z = +950 across X −240 to +240. **Distance is measured on the XZ plane from the player's own Fling Point.** Zones are distance bands. Visual bands are drawn along Z (an approximation for side plots); **the server always uses true distance.**

| # | Zone | Distance | Ground color | Signature props | Sign text |
|---|---|---|---|---|---|
| 1 | Gumdrop Meadow | 0 – 50 | `#7CF25A` lime | gumdrop bushes | "GUMDROP MEADOW" |
| 2 | Taffy Hills | 50 – 120 | `#FFB3D9` taffy pink | striped taffy hills | "TAFFY HILLS" |
| 3 | Lollipop Forest | 120 – 220 | `#5ED8FF` sky | giant swirl lollipop trees | "LOLLIPOP FOREST" |
| 4 | Soda Springs | 220 – 360 | `#B78CFF` grape | fizzing soda geysers (bubble particles) | "SODA SPRINGS" |
| 5 | Sprinkle Peaks | 360 – 560 | `#FFD23F` lemon | frosted mountains with sprinkle dots | "SPRINKLE PEAKS" |
| 6 | Rainbow Rim | 560 – 900 | `#FFFFFF` with a rainbow-striped edge | a giant rainbow arch + floating clouds | "RAINBOW RIM" |

- Distance is clamped to [8, 900]; landing X is clamped to [−230, +230].
- Zone signs are big floating BillboardGuis (visible ≤ 1,100 studs) with an "ⓘ" button that opens the odds (section 4.3).
- Props are decorative, with no collision for flings.
- An invisible wall at Z = +2 keeps players on the terrace.

### 2.3 Jelly Pads (bounce pads)
- **18 Jelly Pads** float 1 stud above the valley: 3 per zone, at fixed positions in `Config.Map.JellyPads`. Spread them across X so each plot has at least one pad roughly in line in zones 2–5.
- Each pad is a wobbly jelly disc of **radius 9**, colored in a rotating sequence: `#FF4FA3`, `#3EC5FF`, `#7CF25A`, `#FFD23F`, `#9B5CFF`, `#FF8A3D`. It plays a client-side idle wobble (scale Y 1 ↔ 0.85, 0.8 s period).
- **Bounce rule (server-computed):** if a fling's landing point lies within a pad's radius, the goo **bounces**. It continues in the same direction for an extra distance = **50% of the previous segment's length**, with a new arc whose apex is 60% of the previous one. Bounces can chain up to **3** times. Each bounce plays a "BOING!" pop with the pad squashing. Distance is clamped to 900 in total. The final landing point decides the zone.
- **Bounce bonus:** each bounce also adds **+1 rarity luck step** for that fling: multiply the Rare+ weights by 1.25 per bounce (so ×1.95 at 3 bounces), then renormalize. The Odds panel says this explicitly.

### 2.4 Hub (behind the terrace, Z −60 to −120)
- **Goo Lab** (X −45, Z −85): ProximityPrompt "Goo" → Upgrades, Goo tab.
- **Glove Stand** (X +45, Z −85): "Gloves" → Upgrades, Gloves tab.
- **Re-Squish Machine** (X 0, Z −105): a giant squeeze-press machine. "Re-Squish" → Re-Squish panel.
- **Squishydex Wall** (X −100, Z −85): "Squishydex" → Squishydex.
- **Leaderboard** (X +100, Z −85): SurfaceGui with the top 10 in-server by Total Squishies Collected.
- All prompts are mirrored by HUD buttons; walking is never required.

---

## 3. Core loop (exact)

1. Player stands at their Slingshot (HRP within 8 studs of the Fling Point).
2. **Pull back:** hold FLING (HUD button, mouse left / Space when at the slingshot, gamepad ButtonR2). The pouch pulls back visibly and a **power meter** fills 0 → 1 → 0 on a **0.9 s** cycle (triangle wave). The **sweet spot** is 0.88–1.00 (gold segment).
3. **Aim:** the mouse cursor on the valley (or A/D / thumbstick while charging, or dragging the THROW finger), clamped to **±30°** from +Z. The preview shows the whole path with bounces and a landing ring (§19).
4. **Release:** the client sends `FlingRequest(charge, yawDeg)`. The server validates (section 6.3), computes the full path including bounces, and broadcasts `FlingVisual`.
5. **Flight:** a goo blob (colored by goo tier) flies a parabola. Segment flight time = `0.35 + segmentLength / 600` s; first apex height = `8 + distance × 0.15`. On each pad hit: a squash, "BOING!" and the next segment.
6. **Splat (server, at the final landing):** zone → rarity roll (zone odds × bounce luck × Goo Rain luck) → species uniform within the rarity → **Glitter** variant roll (1%).
7. **Pop-out:** a splat decal-disc in the goo color, then the squishy pops up (scale 0 → 1.3 → 1.0 over 0.35 s), with a sparkle burst. Rare+ gets a rarity-colored burst; Legendary/Mythic get a beam and a server announcement (section 7.4).
8. **Hop home:** the squishy bounces back toward the owner's Shelf in big arcs at **70 studs/s** horizontal (Goo Rain: 140), each hop squashing on landing. The server arrival time = `distanceToShelf / speed + 0.6` s.
9. **Arrive:** the squishy is added to the Shelf if there's a free slot (section 4.6; otherwise the Shelf Full flow runs), auto-merges if enabled (section 4.5), and records a Squishydex entry.
10. **Earn:** every shelved squishy adds coins **directly to the player's coins every second** (no collection step).
11. **Squeeze:** press SQUEEZE (section 4.4) for an instant burst.
12. **Spend** on Goo, Gloves, Shelf slots and Shelf level → fling farther → rarer → more coins → **Re-Squish**.

- **Reload:** **0.8 s** after release (server-enforced), §19.
- **Max squishies hopping home per player:** 6. When it's reached, the FLING button greys out with "Squishies incoming…".
- **Sling Power (SP):** a persistent stat; each fling grants `+SPPerFling` (base 1; Gloves raise it). Shown on the HUD.

---

## 4. Systems and numbers

### 4.1 Distance formula
```
segment1 = (25 + 22 * sqrt(SP)) * gooMult * reSquishDistMult * gooRainDistMult * chargeCurve(charge)
chargeCurve(c) = 0.35 + 0.65 * c ;  if c >= 0.88 then 1.0 and toast "PERFECT!"
reSquishDistMult = 1 + 0.10 * reSquishes
gooRainDistMult  = 1.25 during Goo Rain, else 1
bounce: next segment = 0.5 * previous segment, up to 3 bounces, total clamped to 900
```
Reference (Bubblegum Goo, perfect, no bounce): SP 1 → 47; SP 25 → 135; SP 100 → 245; SP 400 → 465; SP 900 → 685.

### 4.2 Goo (one-time purchases; the highest owned is auto-equipped)
| Tier | Goo | Cost | gooMult | Blob color / FX |
|---|---|---|---|---|
| 1 | Bubblegum Goo | free | 1.00 | `#FF4FA3` |
| 2 | Lime Slime | 600 | 1.10 | `#7CF25A` |
| 3 | Blue Raspberry | 5,000 | 1.25 | `#3EC5FF` |
| 4 | Grape Gel | 40,000 | 1.40 | `#9B5CFF` |
| 5 | Lemon Fizz | 280,000 | 1.60 | `#FFD23F` + fizz bubbles |
| 6 | Rainbow Goo | 1,800,000 | 1.85 | animated rainbow color cycle + sparkle trail |

All goo uses one low-poly blob mesh (≤ 80 tris), recolored.

### 4.3 Zone rarity odds (free gameplay randomness; always shown)
| Zone | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| 1 Gumdrop Meadow | 85 | 15 | 0 | 0 | 0 | 0 |
| 2 Taffy Hills | 60 | 32 | 8 | 0 | 0 | 0 |
| 3 Lollipop Forest | 35 | 40 | 20 | 5 | 0 | 0 |
| 4 Soda Springs | 0 | 35 | 40 | 20 | 5 | 0 |
| 5 Sprinkle Peaks | 0 | 0 | 40 | 40 | 18 | 2 |
| 6 Rainbow Rim | 0 | 0 | 0 | 45 | 45 | 10 |

- **Bounce luck:** Rare+ weights × `1.25^bounces`, then renormalize.
- **Goo Rain luck** (free scheduled event only): Rare+ weights × 2, then renormalize (stacks with bounce luck).
- **Glitter variant:** 1% per catch; ×3 income; a holographic sparkle shader-look (a sparkle ParticleEmitter + a slight Neon rim).
- The Odds tab shows the table, the bounce multipliers (1/2/3 bounces), Goo Rain values and Glitter 1%.
- **No Robux purchase changes any odds** (section 10.4).

### 4.4 Squeeze (instant burst, fast tapping)
- **SQUEEZE** (HUD button; keyboard **E**; gamepad ButtonX) squeezes **every ready squishy** on your shelf. Each pays **5 s of its final income** instantly, plays a squash animation (scale XZ 1.25, Y 0.7, back with an overshoot, 0.3 s) and a "squish" sound (limit 6 sounds per press), and pops "+X" numbers.
- Each squishy then has a **10 s** squeeze cooldown. The SQUEEZE button shows a fill ring for the share of ready squishies, a pulse when ≥ 50% are ready, and the label "SQUEEZE ×12".
- Server-enforced: ≤ 4 SqueezeRequests/s; squishies on cooldown are skipped.

### 4.5 Merging (the core collection hook)
- **3 identical squishies** (same species, same size, same Glitter state) **merge into 1 of the next size**:
  | Size | Scale | Income multiplier vs Normal |
  |---|---|---|
  | Normal | 1.0 | ×1 |
  | Chonky | 1.4 | ×4 |
  | Mega | 1.9 | ×16 |
- Mega is the max. Merging frees 2 shelf slots.
- **Auto-Merge** (free toggle, default ON): when a squishy arrives and a merge becomes possible, it happens automatically, with an animation: the three squishies hop together, squash into one, and a "MERGE! Chonky Mochi Blob" toast plays.
- With Auto-Merge OFF, the Shelf panel shows a **Merge** button on each stack of 3+.
- Squishydex records the best size reached per species (Normal/Chonky/Mega badges on the card).

### 4.6 Shelf (capacity and level)
- **Slots:** start **8**; each upgrade +2, up to **40** (16 upgrades). Cost: `floor(120 * 2.1^k)` (k = upgrades bought).
- **Shelf Full flow:** if a squishy arrives with no free slot and it can't merge, a modal shows: "Shelf full!" with the new squishy card and your lowest-income squishy card, plus **[Keep new]** / **[Release new]**. Releasing pays **30 s of the released squishy's income**. Auto-choice after **6 s**: keep the higher income. Multiple arrivals queue.
- **Manual release** from the Shelf panel pays 30 s of income (confirm for Epic+ or Chonky+).
- **Shelf Level** (income multiplier + visuals):
  | Level | Cost | shelfMult | Visual |
  |---|---|---|---|
  | 1 | — | 1.00 | plain candy shelf |
  | 2 | 2,000 | 1.10 | + gumdrop lights |
  | 3 | 30,000 | 1.25 | wider, lollipop pillars |
  | 4 | 450,000 | 1.45 | 4 tiers + spinning star topper |
  | 5 | 6,000,000 | 1.70 | rainbow arch over the shelf, sparkles |

### 4.7 Gloves (Sling Power per fling; one-time)
| Tier | Gloves | Cost | SPPerFling | Glove color on avatar |
|---|---|---|---|---|
| 1 | Bare Hands | free | 1 | — |
| 2 | Gummy Gloves | 350 | 2 | `#7CF25A` |
| 3 | Taffy Gloves | 4,000 | 3 | `#FF4FA3` |
| 4 | Soda Gloves | 50,000 | 5 | `#3EC5FF` |
| 5 | Sprinkle Gloves | 600,000 | 8 | `#FFD23F` with sprinkle dots |
| 6 | Rainbow Gloves | 4,000,000 | 12 | animated rainbow |

### 4.8 Squishies (24 total: 4 per rarity; 4 base body meshes)
**Base bodies** (each ≤ 350 tris, smooth-rounded low-poly): **Bun** (round dome), **Loaf** (cat-loaf with ear nubs), **Bean** (tall jellybean), **Blob** (droopy teardrop). Every squishy has the same face: two black oval eyes with a white highlight dot, pink blush ovals `#FF9EC7`, and a tiny "w" mouth (geometry, not decals). Variation comes from body color, one optional accessory (≤ 150 tris) and scale. Income is coins/s for Normal size, before multipliers.

| Rarity (UI color) | Squishy | Body | Color | Accessory | Scale | Income/s |
|---|---|---|---|---|---|---|
| Common `#B8C4D6` | Bao Bun | Bun | `#FFF4E0` | steam swirl | 1.0 | 1 |
| Common | Mochi Blob | Blob | `#FFD6E8` | — | 1.0 | 1 |
| Common | Jelly Bean | Bean | `#FF6B6B` | — | 1.0 | 1.5 |
| Common | Marshmallow | Bun | `#FFFFFF` | toasted top `#E8B98A` | 0.9 | 1.5 |
| Uncommon `#4CD964` | Strawberry Puff | Bun | `#FF4F6E` | leaf cap `#7CF25A` + seed dots | 1.0 | 4 |
| Uncommon | Peach Loaf | Loaf | `#FFB38A` | leaf | 1.0 | 4 |
| Uncommon | Cloud Puff | Blob | `#E6F7FF` | rainbow raindrop | 1.0 | 5 |
| Uncommon | Froggy Jelly | Bean | `#7CF25A` | eye bumps | 1.0 | 5 |
| Rare `#3EC5FF` | Boba Bear | Bun | `#E8C9A0` | boba pearls + straw | 1.0 | 14 |
| Rare | Avocado Pal | Bean | `#9BE36D` | pit belly `#B5651D` | 1.0 | 15 |
| Rare | Sushi Roll | Bun | `#FFFFFF` | nori band `#2B1B4A` + salmon top `#FF8A3D` | 1.0 | 16 |
| Rare | Taco Pup | Loaf | `#FFD23F` | lettuce frill + floppy ears | 1.0 | 18 |
| Epic `#9B5CFF` | Donut Dragon | Loaf | `#FF4FA3` | sprinkle frosting + tiny wings | 1.1 | 50 |
| Epic | Cupcake Cat | Loaf | `#FFE3F1` | cupcake wrapper base `#3EC5FF` + cherry | 1.1 | 55 |
| Epic | Octo Jelly | Blob | `#B78CFF` | 4 tentacle nubs | 1.1 | 60 |
| Epic | Unicorn Puff | Bun | `#FFFFFF` | rainbow horn + mane | 1.1 | 65 |
| Legendary `#FF8A3D` | Galaxy Cat | Loaf | `#2B1B4A` + star sparkles | — | 1.25 | 180 |
| Legendary | Crown Cake | Bun | `#FFE3F1` | gold crown `#FFD23F` | 1.25 | 200 |
| Legendary | Lava Mochi | Blob | `#FF5A1F` (Neon cracks) | ember particles | 1.25 | 220 |
| Legendary | Crystal Bunny | Bean | `#BFF3FF` (Glass, 0.2) | bunny ears | 1.25 | 240 |
| Mythic `#FF2E88` (animated rainbow gradient in UI) | Prism Blob | Blob | rainbow color cycle | prism sparkle | 1.4 | 700 |
| Mythic | Golden Bao | Bun | `#FFD23F` (Neon accents) | gold steam | 1.4 | 800 |
| Mythic | Cosmic Whale | Loaf | `#3A2E8C` + nebula particles | spout of stars | 1.5 | 900 |
| Mythic | Mega Mochi | Blob | `#FFD6E8` | party hat | 2.0 | 1,000 |

Final income = `base × sizeMult × (Glitter ? 3 : 1) × shelfMult × reSquishIncomeMult × (2x Coins pass ? 2 : 1) × (Squish Party ? 2 : 1)`.

### 4.9 Re-Squish (rebirth)
- **Requirement for Re-Squish n:** coins ≥ `2,500,000 × 4^(n−1)` **and** at least one Legendary+ (any size) on the shelf.
- **Resets:** coins, SP → 1, goo → Bubblegum, gloves → Bare Hands, all shelf squishies, slots → 8, shelf level → 1.
- **Keeps:** Squishydex (including best sizes), Re-Squish count, badges, passes, cosmetics, daily streak, lifetime stats, Auto-Merge setting.
- **Grants:** `reSquishIncomeMult = 1 + 0.5 × n`, `reSquishDistMult = 1 + 0.10 × n`, and a sign title ("Re-Squish I, II…"; Roman numerals to X).
- **Panel:** checklist, what's reset and kept, "Income ×1.5 → ×2.0", and a big **RE-SQUISH!** button → confirm "All your squishies get squished into the machine. Ready?" [Re-Squish!] [Not yet] → the machine squishes the screen (a full-screen pink goo wipe, 1.5 s) and you respawn at your slingshot.

### 4.10 Goo Rain (free, scheduled, server-wide)
- Every **12 min** of uptime, starting **4 min** after server start, lasting **90 s**.
- Effects: distance ×1.25, Rare+ luck ×2, hop-home speed ×2, and goo blobs falling from the sky as decor (client).
- 30 s warning: banner "🌈 GOO RAIN in 0:30" + a jingle. During it: an animated rainbow banner with a countdown, the Goo Rain music, sky ColorCorrection tint `#FFF0FA`. The HUD otherwise shows "Next Goo Rain mm:ss".

### 4.11 Offline income
On join: `min(secondsAway, 6 h) × incomePerSecAtLogout × 0.5`. Modal: "Welcome back! Your squishies made **X** coins while you were away (50% rate, up to 6 h)." [Collect]. No upsell.

### 4.12 Daily streak and quests
- **7-day calendar** (UTC; a missed day resets): D1 `max(400, 5 min income)` · D2 `max(900, 10 min)` · D3 +60 SP · D4 `max(3,000, 20 min)` · D5 a free Rare squishy (uniform) · D6 `max(8,000, 45 min)` · D7 a free squishy rolled **Epic 70 / Legendary 28 / Mythic 2** (odds on the tile). Then repeat; the streak keeps counting.
- **3 daily quests** (00:00 UTC), reward `max(1,000, 15 min income)` each, from: Fling 150 times · Land 15 PERFECT flings · Get a triple bounce · Merge 5 times · Squeeze 30 times · Catch 3 Rare+ squishies · Catch a squishy during Goo Rain.
- The Daily button shows a "!" badge when claimable; the panel never auto-opens.

### 4.13 Badges (IDs in config; 0 = skip)
Welcome to Squish Valley · First Rare · First Epic · First Legendary · First Mythic · Glitter Find · Triple Bounce · First Chonky · First Mega · Rainbow Rim (reach zone 6) · Full Shelf (40) · First Re-Squish · Squishydex Complete (24/24).

### 4.14 Leaderstats
**Squishies** (current shelf count) and **Coins** (abbreviated StringValue).

---

## 5. Onboarding (first 60 s; fast)

A pulsing hot-pink arrow (Beam) plus a one-line hint chip at top-center for each step.
1. Teleport to the slingshot. Hint: "Hold FLING, let go in the gold!" The FLING button pulses.
2. **First fling:** treated as PERFECT regardless of release, guaranteed to land on a Jelly Pad in zone 2 for **one bounce** (the server overrides the aim to the nearest zone-2 pad in this player's lane), and guaranteed **Uncommon**. Hint: "BOING! Jelly Pads bounce you farther!"
3. **Arrival:** "Squishies make coins every second! Press SQUEEZE for a burst!" SQUEEZE pulses.
4. **Third fling:** guaranteed to be the same species as one already owned (rigged once), so the player's first merge happens early if they keep going. Then: "Get 3 of the same to MERGE!"
5. Once coins reach 600: "Buy Lime Slime goo to fling farther!" Upgrades pulses.
6. Done after the first goo purchase **or** 10 flings. Save `tutorialDone`.
- Each step logs an onboarding funnel event (section 12).

---

## 6. Technical architecture

### 6.1 Plots
The lowest free plot (1–12) goes to each joiner. The sign shows "Loading…" until data loads, and FLING is disabled. On leave: save, then clear the plot. Plot attributes: `OwnerUserId`, `PlotIndex`.

### 6.2 Folder layout (map to the template's source layout if it prescribes one)
```
ReplicatedStorage/
  Shared/
    Config/   Game, Map, Zones, Squishies, Economy, Monetization, Audio, UI, Badges
    Util/     Format, Signal, Odds (weighted roll + renormalize + multipliers), Trajectory (segments + bounce)
    Net.lua
  Assets/     Squishy bodies (4) + accessories, Goo blob, Slingshot, Shelf L1–L5, Jelly Pad, Re-Squish Machine,
              candy props (gumdrops, taffy hills, lollipops, geysers, peaks, rainbow arch, clouds)
ServerScriptService/
  Main.server.lua
  Services/   DataService, PlotService, FlingService, SquishyService, ShelfService (slots, merge, release),
              SqueezeService, EconomyService, UpgradeService, ReSquishService, GooRainService,
              DailyService, QuestService, MonetizationService, BadgeService, AnnouncementService,
              LeaderboardService, AnalyticsService
StarterPlayer/StarterPlayerScripts/
  Main.client.lua
  Controllers/ HUDController, FlingController (input, charge, aim, procedural slingshot pull), TrajectoryPreview,
               GooFlightRenderer (segments + bounces), SquishyRenderer (pop-out + hop home), ShelfRenderer
               (wobble, squeeze, merge animations), JellyPadController (idle wobble + bounce squash),
               ShopController, SquishydexController, UpgradesController, ShelfPanelController, ReSquishController,
               DailyController, NotificationController, AudioController, SettingsController, TutorialController,
               WeatherController (Goo Rain FX)
```

### 6.3 Remotes (server-validated and rate-limited)
| Name | Dir | Payload | Validation |
|---|---|---|---|
| FlingRequest | C→S | charge, yawDeg | at own slingshot (≤ 8 studs); cooldown 0.5 s; hopping < 6; clamp charge [0,1], yaw ±30; ≤ 4/s |
| FlingVisual | S→All | ownerUserId, startPos, segments {endPos, time, apex}, gooTier, perfect | — |
| SquishySpawned | S→All | ownerUserId, uid, speciesId, glitter, landPos, arriveAt | — |
| ShelfUpdate | S→C | full shelf array {uid, s, size, glitter, readyAt} | on change |
| ShelfFullChoice | C→S | keepNew | pending choice exists |
| SqueezeRequest | C→S | — | ≤ 4/s; squeezes ready squishies only |
| MergeRequest | C→S | speciesId, size, glitter | ≥ 3 matching; size < Mega |
| ReleaseSquishy | C→S | uid | owned |
| SetAutoMerge | C→S | bool | — |
| BuyUpgrade | C→S | kind ("goo"/"gloves"/"slots"/"shelf"), tier | next tier; affordable |
| ReSquish | C→S | — | requirements |
| ClaimDaily / ClaimQuest | C→S | index | — |
| StateSync | S→C | coins, incomePerSec, SP, goo, gloves, slots, shelfLevel, reSquishes, gooRain times, quests, daily, autoMerge | throttled 5/s |
| Announce | S→All | text, rarity | — |
| SettingsSave | C→S | {music, sfx, lowGraphics} | — |

All cross-client timing uses `workspace:GetServerTimeNow()`.

### 6.4 Data (DataStore `FAS_PlayerData_v1`, key `u_<UserId>`)
```lua
{
  version = 1,
  coins = 0,
  sp = 1, goo = 1, gloves = 1, slotUpgrades = 0, shelfLevel = 1,
  reSquishes = 0,
  shelf = { {uid="…", s="bao_bun", z=1, g=false}, ... },   -- z: 1 Normal, 2 Chonky, 3 Mega; max 40
  dex = { bao_bun = {n=5, best=2, glitter=false}, ... },
  autoMerge = true,
  daily = { lastClaimDay = 0, streak = 0, cycleDay = 0 },
  quests = { day = 0, list = { ... } },
  stats = { flings=0, perfects=0, bounces=0, tripleBounces=0, caught=0, merges=0, squeezes=0, highestZone=1, totalEarned=0, playSeconds=0 },
  tutorialDone = false,
  settings = { music=true, sfx=true, lowGraphics=false },
  lastOnline = 0, lastIncomePerSec = 0,
  receipts = { }
}
```
- Load with 3 retries (1/2/4 s). On failure, kick with "Couldn't load your data, please rejoin." Never run on defaults that could overwrite real data.
- Save with `UpdateAsync` every 90 s, on leave, and in `BindToClose` (≤ 25 s). Squeeze cooldowns aren't saved (everything is ready on join).
- **Studio without API access:** in-memory data, one warning, no crash.

### 6.5 Anti-exploit
The server owns all numbers, paths, rolls, arrivals, merges and income. Clients send intents only. Income is ticked server-side once per second as an aggregate. Every remote is rate-limited; excess is dropped silently.

### 6.6 Performance budgets
- Shelf squishies: anchored, no Humanoids, pooled. Clients render their own shelf always and others within 160 studs (max 40 per plot). Wobble (scale Y ±4%, 1.6 s period, random phase) runs only within 100 studs.
- In-flight goo: pooled, max 72. Hopping squishies: pooled, max 72.
- Particles: Goo Rain decor blobs, rate 20 (Low Graphics off). Mythic beam 2 s.
- Target: mobile 60 FPS with 12 players; server heartbeat ≥ 55.

---

## 7. UI (exact layout)

UIScale from viewport (base 1920×1080; clamp 0.6–1.2; mobile touch targets +15%).

### 7.1 Style tokens (bright candy)
- **Fonts:** headers `Enum.Font.FredokaOne`; body/numbers `Enum.Font.GothamBlack` for big numbers and `Enum.Font.GothamBold` for text; small `Enum.Font.GothamMedium`.
- **Panels:** background `#FFFFFF`, UICorner 22, UIStroke 4 `#2B1B4A`, padding 18, a top header strip with a UIGradient `#FF4FA3` → `#9B5CFF` and white FredokaOne title.
- **Buttons:** chunky with a 4-stud "bottom lip" (a darker duplicate frame offset 4 px down) for a 3D candy-button look. Primary `#FF4FA3` (lip `#C2286F`); secondary `#3EC5FF` (lip `#1E8FC2`); success `#7CF25A` (lip `#4DB52E`); disabled `#D9D4E6` (lip `#AFA8C2`). Text white with a UIStroke 2 `#2B1B4A`. **Press:** the button moves down 4 px onto its lip for 0.06 s and scales 0.95; release bounces to 1.04 then 1.0 (0.15 s).
- **Juice rules:** every number change tweens (count-up over 0.25 s), every new toast pops in with a 1.15 → 1.0 overshoot, and coin gains spawn 3–8 coin icons that fly to the coin counter (pooled, max 30).
- **Rarity colors:** see the 4.8 table. Mythic uses an animated rainbow UIGradient (rotation 0→360 over 2 s).
- **Number abbreviations:** K, M, B, T, Qa, Qi.
- **Emoji fallbacks when icons are missing:** Coins 🪙, Squishies 🍡, SP 💪, Shop 🛒, Dex 📖, Upgrades ⬆️, Shelf 🧸, Daily 📅, Settings ⚙️, Re-Squish 🔄.

### 7.2 HUD
- **Top-left stack** (offset 24,24): Coins pill (🪙 + abbreviated, GothamBlack 38) with "+X/s" under it; Shelf pill "🍡 18 / 24" (tap → Shelf panel); SP pill "💪 SP 154 (+3/fling)".
- **Top-center:** Goo Rain chip "Next Goo Rain 05:12" → animated rainbow banner during the event. Hint chip below.
- **Left vertical buttons** (88×88 candy buttons, gap 12): Shop, Squishydex, Upgrades, Shelf, Daily ("!").
- **Bottom-center:** **FLING** button, 190×190 circle (mobile 220×220), `#FF4FA3` with a lip, white "FLING" FredokaOne 42. A ring-shaped power meter around it fills lime → lemon → hot pink, with the gold sweet-spot segment. When not at the slingshot it's replaced by the pill "Back to your slingshot" with an arrow.
- **Bottom-right:** **SQUEEZE** button, 150×150 circle `#3EC5FF`, label "SQUEEZE ×N" and a ready-fill ring; it pulses when ≥ 50% are ready. A small Auto-Merge toggle chip sits above it ("Auto-Merge: ON").
- **Bottom-left:** Re-Squish button (120×60 pill, grape `#9B5CFF`), glowing when ready; Settings ⚙️ (small) above it.
- **Right edge:** toast stack (max 4, 2.5 s): "PERFECT!", "BOING ×3!", "MERGE! Chonky Boba Bear", "New squishy: Taco Pup!", quest progress.
- **In-world pops:** "BOING!" text pops at pads (BillboardGui, 0.6 s); "+X" coin pops over squeezed squishies.

### 7.3 Panels (center modal 920×640, ✕ / Esc / B closes, one at a time; 0.15 s bounce-in)
1. **Shop:** tabs **Passes | Coins**. 4 pass cards (2×2; Owned ✓); 3 coin cards showing the exact amount now; the Squish Party card with the active timer.
2. **Squishydex:** 24 cards by rarity; silhouettes with "???" until caught. Caught cards show name, income/s, times caught, a best-size badge (N / C / M) and a ✨ for Glitter. Header "17 / 24". Tab **Odds:** the zone table, bounce multipliers, Goo Rain luck, Glitter 1%.
3. **Upgrades:** tabs **Goo | Gloves | Shelf** (slots + level). Rows with icon, name, effect, cost, [Buy] / [Owned] / [Locked] (only the next tier is buyable).
4. **Shelf:** a grid of squishies grouped by species and size with counts ("×2 — 1 more to merge!"); [Merge] buttons when Auto-Merge is off; [Release] per item; sort toggle (Income / Rarity / Newest).
5. **Daily:** the 7-tile calendar + 3 quests.
6. **Re-Squish:** section 4.9.
7. **Settings:** Music, SFX, Low Graphics (disables Goo Rain decor, bloom, shelf wobble for other plots; halves particles).

### 7.4 Pop-ups
- **Catch reveal card** (Rare+; top-center; 2 s; non-blocking): rarity banner, name, income/s, "NEW!" if first.
- **Merge celebration** (Chonky/Mega; 1.5 s): the card grows with a star burst.
- **Shelf Full** (4.6), **Welcome back** (4.11), **Re-Squish confirm** (4.9).
- **Server announcement** (Legendary/Mythic catch, and any Mega merge of a Legendary+): top banner 4 s "⭐ [Name] flung a MYTHIC Golden Bao!" in the rarity color; Mythics also play a global fanfare.

---

## 8. Audio

**Sourcing rule:** only free, experience-usable audio from the Roblox Creator Store (licensed music catalog or Roblox-uploaded SFX). Find candidates with the Studio MCP asset search using the queries below, record the IDs in `Config.Audio` and list them in the PR. Never use commercial songs or rips. ID `0` = skip silently.

### 8.1 Music (SoundGroup "Music", volume 0.35, 1.2 s crossfades)
| Slot | When | Search query | Criteria |
|---|---|---|---|
| main_theme | default | "bubbly happy kids" / "candy pop upbeat" | 120–135 BPM, major key, bouncy synth/marimba, no vocals, ≥ 90 s loop |
| goo_rain | Goo Rain | "fast happy chiptune" / "hyper fun upbeat" | 140–160 BPM, no vocals |
| resquish_sting | Re-Squish wipe | "magical swoosh sparkle" | ≤ 3 s |

### 8.2 SFX (SoundGroup "SFX", volume 0.6)
| Slot | Trigger | Search query |
|---|---|---|
| sling_stretch | while charging (pitch 0.9→1.4 with charge) | "rubber stretch" |
| sling_release | release | "slingshot twang" |
| perfect | PERFECT | "sparkle ding" |
| boing | Jelly Pad bounce (pitch +10% per chained bounce) | "boing cartoon" |
| splat | goo lands | "slime splat" |
| pop_out | squishy appears | "cute pop" |
| hop | squishy hop landing (3D, low volume, max 4 per 0.2 s) | "soft bounce" |
| squish | squeeze (pitch ±10%, max 6 per press) | "squishy squeeze" |
| merge | merge | "level up chime" |
| coin_burst | squeeze payout | "coins sparkle" |
| buy | purchase | "purchase pop cute" |
| rare_reveal | Rare/Epic | "reward jingle" |
| legendary_fanfare | Legendary/Mythic | "fanfare victory short" |
| goo_rain_jingle | 30 s warning | "magic jingle" |
| ui_click / ui_error | UI | "ui click pop" / "ui error soft" |
| ambient | constant, vol 0.12 | "happy birds meadow ambience" |

---

## 9. Visual direction (bright candy low-poly)

### 9.1 Rules
- Flat-shaded low-poly Blender meshes with **rounded, chunky silhouettes**; solid colors via MeshPart `Color`; no textures (UI icons only). `SmoothPlastic` default; `Neon` for small glows (Lava Mochi cracks, Golden Bao accents, sweet-spot highlights); `Glass` for Crystal Bunny.
- **Squash-and-stretch everywhere:** every pop, landing, squeeze and button uses overshoot tweens (`Enum.EasingStyle.Back` or `Elastic` Out). Nothing appears instantly.
- Triangle budgets: squishy body ≤ 350, accessory ≤ 150, goo blob ≤ 80, slingshot ≤ 500, shelf L1 ≤ 800 / L5 ≤ 2,500, jelly pad ≤ 120, props ≤ 500.

### 9.2 Palette (saturated candy)
| Token | Hex | Use |
|---|---|---|
| hot pink | `#FF4FA3` | primary, Bubblegum |
| sky | `#3EC5FF` | secondary, Blue Raspberry |
| lime | `#7CF25A` | success, Lime Slime, meadow |
| lemon | `#FFD23F` | gold, Lemon Fizz |
| grape | `#9B5CFF` | Grape Gel, headers |
| orange | `#FF8A3D` | accents |
| taffy | `#FFB3D9` | hills |
| cream | `#FFE3F1` | terrace, shelves |
| ink | `#2B1B4A` | outlines, text strokes, eyes |
| white | `#FFFFFF` | highlights |

### 9.3 Lighting (boot `LightingSetup`)
`Technology = ShadowMap`, `ClockTime = 12.5`, `Brightness = 3`, `Ambient = #B9A8E6`, `OutdoorAmbient = #D9CFF5`, `ColorShift_Top = #FFF0D6`, `EnvironmentDiffuseScale 0.6`, `EnvironmentSpecularScale 0.3`.
Atmosphere: Density 0.22, Offset 0.05, Color `#FFE6F5`, Decay `#C9B8FF`, Haze 0.8, Glare 0.
ColorCorrection: **Saturation +0.18**, Contrast 0.08, Tint `#FFFBFE` (Goo Rain: `#FFF0FA`). Bloom: Intensity 0.45, Size 20, Threshold 1.4 (off in Low Graphics). Default Sky, CelestialBodiesShown false; 12 low-poly cotton-candy clouds (`#FFD6E8`, `#D6E8FF`) drift slowly across the sky (client, 2 studs/s).

### 9.4 Animations (procedural, no animation assets)
- **Slingshot pull:** the pouch moves back up to 4 studs (proportional to charge) and the bands (two Beams) stretch. The player's right-shoulder Motor6D `C0` rotates back up to 60°. On release: the pouch snaps forward over 0.08 s, overshoots 1 stud, and settles over 0.2 s. The arm swings forward −30° and returns over 0.25 s.
- **Squishy idle:** scale Y 1 ↔ 0.96 wobble (1.6 s), with an occasional happy hop (every 6–14 s, random).
- **Hop home:** arcs of 18-stud horizontal length, apex 6; squash (Y 0.7, XZ 1.2) for 0.08 s on each landing.

### 9.5 Camera
Default follow camera. While charging, FOV tweens 70 → 62 (0.15 s). On a triple bounce, a 0.1 s FOV kick of +4 for juice. No forced camera cuts except the Re-Squish wipe.

---

## 10. Monetization (medium, by Rayyan's rules)

There's no PvP. A free path to everything. **No purchase prompt on join.** No paid randomness. Odds are always shown.

### 10.1 Game passes (IDs in config; 0 = "Coming soon" card, disabled)
| Pass | Price | Effect |
|---|---|---|
| **2× Coins** | 299 R$ | ×2 squishy income (also doubles squeeze bursts, since those are based on income) |
| **Auto-Fling** | 199 R$ | HUD toggle (shown only if owned): while at your slingshot, flings every 1.5 s at charge 0.80 (never PERFECT), aimed straight; pauses when you move |
| **Auto-Squeeze** | 149 R$ | squeezes all ready squishies automatically every 10 s |
| **Rainbow Trail** | 79 R$ | cosmetic rainbow trail on your goo + a rainbow name sign. No gameplay effect |

### 10.2 Developer products
| Product | Price | Grant |
|---|---|---|
| **Coin Bag** | 49 R$ | `max(5,000, 10 min of current income)` |
| **Coin Jar** | 149 R$ | `max(25,000, 45 min)` |
| **Coin Tub** | 399 R$ | `max(120,000, 3 h)` |
| **Squish Party** | 99 R$ | server-wide ×2 income for **everyone** for 5 min (stackable +5 min, max 30 min queued). Banner "🎉 [Name] started a Squish Party! 2× coins for everyone!" Income only; never odds |

"Current income" is the buyer's income/s including all multipliers except Squish Party. The Shop card shows the exact amount.

### 10.3 Purchase handling
`ProcessReceipt` is idempotent via `receipts` (last 50 IDs). Grant → save with `UpdateAsync` → return `PurchaseGranted`; if not loaded, return `NotProcessedYet`. Passes: `UserOwnsGamePassAsync` on join (pcall, cached), plus `PromptGamePassPurchaseFinished`. Prompts fire only from Shop buttons or the locked Auto-Fling / Auto-Squeeze toggles (those open the Shop to the pass card; they never prompt directly).

### 10.4 Policy compliance
No paid random items: no Robux eggs, capsules, crates, spins or luck boosts. All rarity randomness comes from free gameplay (flings, the Day 7 reward). Squish Party affects income only. Odds are displayed anyway.

---

## 11. Store page and launch assets

- **Title:** `Throw a Squishy 🍡`
- **Description (paste exactly):**
  "THROW goo across Squish Valley and catch the cutest squishies! 🍡💥
  The farther you throw, the rarer the squishy, so bounce off JELLY PADS to go even farther!
  ⭐ Collect 24 squishies (and shiny GLITTER ones!)
  🧸 MERGE 3 into a CHONKY, then 3 Chonkies into a MEGA!
  👐 SQUEEZE your squishies for instant coins
  🌈 GOO RAIN every 12 minutes, with double luck!
  🔄 Re-Squish for permanent boosts
  Your squishies earn coins even while you're away!"
- **Icon concept (512×512):** a giant Mega Mochi squishy mid-squash with a happy face, flying hot-pink goo splats around it, a lemon-yellow starburst background; no text.
- **Thumbnail 1:** a slingshot mid-fling; a goo blob bouncing off three jelly pads (motion arcs) toward the rainbow arch; a Mythic Prism Blob bursting out. Text "BOUNCE = RARER!" (FredokaOne, white, thick ink stroke).
- **Thumbnail 2:** the shelf packed with Normal → Chonky → Mega squishies of the same species. Text "MERGE TO MEGA!"
- **10-second clip** (real gameplay, no voiceover): hold → PERFECT → BOING-BOING-BOING → Rainbow Rim splat → Mythic reveal + server banner → it hops home → the third copy arrives → MERGE to Chonky → SQUEEZE coin burst.
- **Publish settings for Rayyan:** Genre Simulation; Max players 12; R15; voice chat off; text chat default; maturity questionnaire: no violence, no gambling (no paid random items).

---

## 12. Analytics (pcall-wrapped)
- Onboarding funnel: 1 Joined, 2 FirstFling, 3 FirstBounce, 4 FirstSquishyArrived, 5 FirstSqueeze, 6 FirstMerge, 7 FirstUpgrade, 8 TutorialDone.
- `LogEconomyEvent`: sources (Income, Squeeze, Release, Offline, Daily, Quest, DevProduct); sinks (Goo, Gloves, Slots, ShelfLevel, ReSquish reset).
- Custom events: "CatchRarity" (rarity index), "Bounces" (0–3 per fling, sampled 1 in 10), "MergeSize" (2 or 3), "ReSquish" (n).

---

## 13. Config modules
- `Config.Game`: MaxPlayers 12, FlingCooldown 0.5, MaxHopping 6, ChargeCycle 0.9, SweetSpot 0.88, AimClampDeg 30, HopSpeed 70, AutosaveInterval 90, OfflineRate 0.5, OfflineCapHours 6, SqueezeCooldown 10, SqueezeSeconds 5.
- `Config.Map`: plot positions, zone bands and colors, Jelly Pad positions (18) and radius 9, MaxBounces 3, BounceDistanceFactor 0.5, BounceApexFactor 0.6, BounceLuckPerBounce 1.25.
- `Config.Zones`: odds, Goo Rain luck ×2, Glitter chance 0.01, Glitter mult 3.
- `Config.Squishies`: the 24 rows (id, name, rarity, body, color, accessory, scale, income), size multipliers {1, 4, 16}, size scales {1, 1.4, 1.9}.
- `Config.Economy`: goo, gloves and shelf-level tables; slot formula (120, 2.1, start 8, step 2, max 40); Re-Squish params (2.5e6, ×4, +0.5 income, +0.10 distance); release payout 30 s; daily and quest tables.
- `Config.Monetization`, `Config.Audio`, `Config.UI`, `Config.Badges` (IDs default 0).

**Boot validation (also a `tools/check.sh` test):** every zone's odds sum to 100; exactly 4 species per rarity; unique IDs; costs strictly increase within each table; every Jelly Pad lies inside the valley bounds and inside a zone band (not across a boundary). `error()` on failure.

---

## 14. Balance targets (sim or estimate in the PR)
Assume a fling every 0.9 s on average, 60% perfect, ~1 bounce per 4 flings in zones 2–5, optimal purchases, Auto-Merge on:
- First Rare ≤ 5 min · first Chonky ≤ 6 min · first Epic ≤ 20 min · first Legendary ≤ 60 min · Rainbow Rim 1.5–2.5 h · Re-Squish 1 in 3–4 h.
- Shelf 20 slots by ~45 min.
If off by more than ±30%, tune costs (slot multiplier 2.1, goo/glove costs) first, never odds.

---

## 15. Acceptance checklist
1. A 2-player Studio playtest runs 5 min with **zero errors** (warnings only for API access or 0 IDs).
2. Onboarding steps 1–6 complete, including the rigged first bounce.
3. Fling → (bounces) → splat → roll → pop-out → hop home → shelf +1 → coins/s rises. Works on PC and the mobile emulator.
4. Bounces chain up to 3 with correct distances and luck multipliers. The Odds panel matches config.
5. All 6 zones are reachable (Studio-only debug command to set SP: `RunService:IsStudio()`).
6. Squeeze pays 5 s of income per ready squishy and respects the 10 s cooldown.
7. Merge: 3 identical → next size, frees 2 slots, with correct multipliers. Auto-Merge on and off both work.
8. Shelf Full modal + 6 s auto-choice work.
9. Goo, gloves, slots and shelf level apply their effects; shelf visuals change per level.
10. Re-Squish resets and keeps exactly what section 4.9 says.
11. Goo Rain triggers on schedule (Studio-only force command) with all effects and music.
12. Offline income, daily rewards and quests persist across a rejoin.
13. With all IDs = 0 the Shop shows "Coming soon" and nothing errors. No prompt appears without a Shop click.
14. Config validation passes. Leaderstats show Squishies and Coins.
15. Low Graphics disables Goo Rain decor and bloom.

---

## 16. Out of scope for v1 (do NOT build)
Trading, PvP, pets following the player, eggs/capsules/crates of any kind, a premium currency, multiple maps, custom squishy creation, voice features.

## 17. Update 2 plan (reference only; do not build)
"[UPD2] Squishy Cafe": 4 dessert-themed squishies (Matcha Roll, Churro Pup, Waffle Bear, Shaved-Ice Bunny) in a limited "Frosting Falls" zone 7 (900–1,100); a Jelly Pad that moves along a track; and a shelf "theme" cosmetic set.

---

## 18. Builder's open decisions (kept current)

Where the spec is silent or conflicts with the template; Rayyan can overrule any of these.

- **Template mapping.** `Net.lua` → `Kit.Net`; DataService → `Kit.Data` (store `FAS_PlayerData_v1`;
  the kit's own retry/session-lock/autosave/BindToClose replace §6.4's hand-written schedule);
  MonetizationService receipts → `Kit.Shop`. Services/Controllers are ModuleScripts with `start()`
  under the template's `Server` and `Client` scripts.
- **Icons are pictures** (`art/icons` → `Kit.Icon`); the §7.1 emoji show only until CI uploads the sheet.
- **Rendering:** the server computes paths, rolls and `arriveAt`; clients animate goo, pop-outs and
  hops from server time. Other players' shelves are published as a compact plot attribute and
  rendered by each client within 160 studs.
- **Rigged first fling:** ignores SP/charge; segment 1 ends at the centre of the zone-2 pad nearest the
  player's lane, then one 50% bounce. The pad layout guarantees one zone-2 pad within ±30° of every plot.
- **Offline income** is in the spec, though an earlier game's feedback called it unnecessary; built as written.
- **Studio-only `Dev` remote** (set SP, force Goo Rain, add coins) for the §15 checks.
- **Rebalance (2026-11-20, approved by Rayyan's "continue" after the PR 1 report).** The spec's own
  numbers reached the Rim in ~2 min. Changed: distance `25 + 1.2·√SP` (was 22·√SP), so goo and gloves
  carry the early climb; goo/glove/shelf prices ×20, except the first goo/glove tier (2,000 / 1,200)
  so the tutorial's buy stays quick; slots `floor(20,000 × 2.4^k)`; Re-Squish `2.5B × 4^(n−1)`.
  Odds and squishy incomes are unchanged. Sim (`lune run tests/local/run.luau balance`, median of 5):
  Lime Slime 0:42 · first Rare 2:28 · first Epic 13:31 · first Legendary 46:00 · 20 slots 32:12 ·
  Rainbow Rim 1:36 · Re-Squish affordable 3:03.
- **PR 2 calls (2026-11-20).**
  - Offline income is paid on join; the modal's [Collect] only plays the coin fly. The saved rate
    is refreshed on every shelf change and zeroed by Re-Squish (no offline pay at the old rate).
  - Re-Squish is refused while any squishy is still hopping home (the checklist says why).
    Squishies flung just before it would otherwise be lost.
  - Quests count one per event (a merge to Mega counts as 1 merge). Rare+ and Goo Rain catches
    count when the squishy reaches the shelf.
  - The left HUD menu is a 2-column grid under the stat pills (Dex, Upgrades, Shelf, Daily,
    Settings, Shop in PR 3); a single column of 6 overlapped the pills on 700 px screens.
    Re-Squish is the bottom-left pill.
  - Shelf level visuals: L2 gumdrop light string, L3 lollipop pillars at the front corners, L4 a
    spinning gold star topper, L5 a rainbow arch behind the shelf with sparkles. The shelf itself
    doesn't widen at L3 or gain a 4th tier at L4.
  - Audio is licensed only (APMOfficial music, ProSoundEffects SFX). Slots with no licensed match
    yet stay 0 (silent): sling_stretch, sling_release, perfect, boing, hop, merge, buy,
    legendary_fanfare, goo_rain_jingle, ui_click, ui_error, ambient.
  - Badge ids are 0 until the badges are created on the Creator Dashboard (Rayyan's account step).
- **PR 3 calls (2026-11-20).**
  - Shop: own panel (Passes | Coins), 2×2 cards, dearest pass first. Items with no id outside Studio
    show "Coming soon" (disabled); Studio grants them free. No passive or join prompt anywhere (§15.13).
  - Auto-Fling / Auto-Squeeze toggles appear on the HUD only once owned (§10.1); there are no locked
    teaser toggles, so §10.3's "locked toggles open the Shop" doesn't apply. Auto-Fling starts OFF each
    session, Auto-Squeeze ON. Both run on the server (1.5 s / 10 s); Auto-Fling needs you standing still
    within reach of your slingshot.
  - Coin packs pay `max(floor, minutes × income without the party)`; the card shows the exact amount
    from the server's `BaseIncome` attribute.
  - Squish Party: +5 min per purchase from max(now, current end), capped at 30 min from now; the card
    turns "Party is full" past 25 min queued. A pill above FLING shows the timer while it runs.
  - Rainbow Trail: a Trail on the owner's goo (drawn by every client) and a rainbow gradient on the
    owner's plot sign name. No particles on the avatar.
  - Game page art (icon + thumbnails, §11) moves to its own PR.
- **Page art calls (2026-11-20).** In `marketing/` (see its README). Everything is the real game:
  staged in the real map in Studio with the real "bacon hair" avatar and the game's own squishy,
  goo, pad and slingshot models, then finished with type in `marketing/compose.py`.
  - Icon: the Mega Mochi (with its party hat) slightly squashed on a lemon starburst with goo splats.
  - Thumbnail 1 "BOUNCE = RARER!": as §11, staged by the plot's slingshot rather than mid-pull (the
    pull pose hid the avatar's face); a MYTHIC tag on the Prism Blob.
  - Thumbnail 2 "MERGE TO MEGA!": Normal → Chonky → Mega strawberry puffs with their real income
    multipliers (x1, x4, x16) instead of a packed shelf, which reads poorly at thumbnail size.
  - Thumbnail 3 "COLLECT ALL 24 SQUISHIES": the avatar in a crowd of Rare-to-Mythic squishies.
  - The 10-second clip is still to do (needs a screen recording of a real fling; Rayyan's call).
- **Renamed to Throw a Squishy (2026-11-21, Rayyan: "dont like fling i like throw more").** Every
  player-facing "fling" is now "throw": the game name, the THROW button, tutorial, quests, upgrade
  text, banners ("threw a MYTHIC …"), the Auto-Throw pass and the page text. Internal names
  (`Fling` modules, `FlingRequest`, `auto_fling`, save field `flings`, analytics `FirstFling`) stay,
  so saves, pass ids and dashboards carry over. The rest of this document still says "fling"; read
  it as "throw".

## 19. Throw feel rework (2026-11-25)
Rayyan: the throw felt odd, spamming won, aim and power didn't work. Changes:
- **No spam:** a press under `MinHold` 0.2 s throws nothing ("Hold to charge!"); a 0.8 s reload
  after each throw (the ring refills in grape, "LOADING"), and holding through the reload starts
  the charge the moment the squishy loads. The server checks both.
- **Power matters:** meter cycle 0.9 → 1.6 s (0.24 s PERFECT window), floor 0.35 → 0.2, PERFECT
  = ×1.1 distance (past a full charge) and **×2 Sling Power**. The label says "NOW!" in the band.
- **PERFECT streak:** consecutive PERFECTs (cap 5) add +5% distance each after the first;
  toast "PERFECT ×3!" with a chime that climbs. A non-perfect manual throw resets it; Auto-Throw
  leaves it alone and is never PERFECT.
- **Aim:** the mouse cursor on the valley; A/D, arrows or the thumbstick steer while charging
  (the player stands still while charging); on phones, drag the THROW finger sideways. Only the
  finger that pressed THROW releases it (lifting the move thumb no longer throws).
- **Preview:** the whole path including pad bounces, plus a landing ring in the zone colour (gold
  when it bounces) labelled with the zone name and "BOING ×n".
- Per-throw time goes from ~0.9 s to ~1.5 s; the balance sim still lands every milestone in range.
