# Game page art

Loud, bright thumbnails in the style of the top Roblox sims, made from the **real game**: each
shot is staged in the real Squish Valley map in Studio with the real Roblox avatar and the game's
own squishy, goo, jelly pad and slingshot models. `compose.py` adds the type, a white sticker
outline, glows and sparkles. Nothing is AI-generated or modelled to look like an avatar.

The avatar is the real catalog look: Pal Hair (63690008), Blue and Black Motorcycle Shirt
(144076358), Dark Green Jeans (144076760), the Robloxian 2.0 R15 body (bundle 311), white, the
classic head and smile.

Upload these in the Creator Dashboard (CI doesn't):

| File | Where |
|---|---|
| `icon.png` (512×512) | Experience icon: the Mega Mochi in its party hat on a lemon starburst with goo splats. No text: it shows at about 150 px in lists |
| `thumbnail_1_bounce.png` | BOUNCE = RARER!: the avatar cheers by the slingshot; the goo bounces off a jelly pad up to a Mythic Prism Blob |
| `thumbnail_2_merge.png` | MERGE TO MEGA!: Normal → Chonky → Mega strawberry puffs, x1 → x4 → x16 coins |
| `thumbnail_3_collect.png` | COLLECT ALL 24 SQUISHIES: the avatar in a crowd of Rare-to-Mythic squishies |

The thumbnails are 1920×1080. Turn on **thumbnail personalization** so Roblox picks the best one.
Every claim is true: bouncing raises rarity, the size multipliers are `Config.Squishies.SizeMult`
(1, 4, 16), and there are 24 species.

## How they're made
1. Studio (Edit) with the game synced (`tools/studio/sync_snippet.luau`). Serve
   `marketing/studio_stage.luau` from the build server (copy it to
   `~/code/roblox-pipeline-builds/studio/`) and load it as a ModuleScript (`HttpService:GetAsync`,
   `require`). It defines `_G.avatar`, `_G.squishy`, `_G.goo`, `_G.pad`, `_G.sling`, `_G.hide`,
   `_G.hideSigns`, `_G.hideGizmos`, `_G.mask` and `_G.clear`. Nothing is saved: the next sync
   rebuilds the workbench.
2. Stage a shot, `screen_capture` it, then `_G.mask(true)` and capture again from the same camera
   (every staged part flat white, the map hidden). Save both as `captures/<shot>.jpg` and
   `captures/<shot>_mask.jpg`. One capture per turn. `_G.clear()` puts everything back.
   The cameras used (Studio viewport 1563×1080, FOV 70):
   - `bounce`: (-24, 5.5, -12) → (-8, 9, 18), plot 6's slingshot, pad and arcs placed in screen space
   - `merge`: (-15, 6, -1) → (-16, 5.5, -30), plot 6, slingshots of plots 5-7 hidden
   - `collect`: (-15, 6.5, -1) → (-15, 6.5, -30), same plot
   - `icon`: (0, 606.5, 12) → (-0.6, 604.6, 0), the Mega Mochi alone high in the sky
3. `python3 marketing/compose.py` writes the PNGs here. Each thumbnail's words and the boxes its
   glows and labels use (in capture pixels) are in `thumb_bounce`, `thumb_merge`, `thumb_collect`.

## Game page text (paste-ready, DESIGN §11)

**Title:** `Fling a Squishy 🍡`

**Description** (under 1,000 characters; if the filter refuses it, save the title alone first,
then the description in halves to find the line):

```
FLING goo across Squish Valley and catch the cutest squishies! 🍡💥
The farther you fling, the rarer the squishy, so bounce off JELLY PADS to go even farther!
⭐ Collect 24 squishies (and shiny GLITTER ones!)
🧸 MERGE 3 into a CHONKY, then 3 Chonkies into a MEGA!
👐 SQUEEZE your squishies for instant coins
🌈 GOO RAIN every 12 minutes, with double luck!
🔄 Re-Squish for permanent boosts
Your squishies earn coins even while you're away!
```

**Settings:** Genre Simulation; Max players 12; R15; voice chat off; text chat default.
Questionnaire: no violence, no gambling (no paid random items).
