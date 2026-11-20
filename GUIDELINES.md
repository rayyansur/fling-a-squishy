# Rayyan's guidelines

Claude reads this before every task. Edit it any time to change how games get made.

## Ship gate (all must pass before merge)
- `tools/check.sh` green: builds, no type errors, valid property names, structure + budget.
- Studio pass: every view screenshotted and reviewed; a playtest shows no game errors.
  (If the Mac/Studio is unreachable, say so in the PR and report.)
- CI green: art uploaded, TEST place published, crash test inside Roblox passes.

## Priorities
1. Doesn't crash, doesn't error.
2. Matches the idea and the art direction Rayyan gave.
3. Looks finished: real Blender models for anything curved or detailed, readable UI, good lighting.
"Fun" is Rayyan's call after he playtests.

## Design
- Every game is designed fresh from the idea. No stock templates or reused game logic unless
  Rayyan asks.
- Art style: Rayyan decides. Ask once if the idea doesn't say.
- Max players: Claude picks per game and notes why in DESIGN.md (co-op/social 4-8,
  round-based 8-16, open hangout up to 30).

## Monetization: medium
- 2-4 game passes and 2-4 developer products per game, priced in the usual Roblox ranges.
- Everything is earnable or optional for free players; paid items speed things up or are
  cosmetic. No pay-to-win against other players, no paywall on the core loop.
- At most one passive purchase prompt per session (e.g. after a milestone), never on join.
- Paid random items always show their odds in the UI.
- Passes and products are declared in `game/monetization.json`; CI creates them in the test
  universe (and in the live one when Rayyan publishes) and fills in the ids. In Studio, items
  without an id grant for free so they can be tested.
- Free hooks are fine: daily reward, codes, group bonus if Rayyan gives a group ID.

## Budgets (pipeline.json, enforced)
- Parts ≤ 15,000 · lights ≤ 200 · particle emitters ≤ 60 · scripts ≤ 200.
- Each Blender model ≤ 10,000 triangles.

## Code
- Server is the source of truth; validate every remote's arguments and rate-limit them.
- Save player data with retries and session-safe writes; never wipe data on a failed load.
- Every feature gets a `tests/cloud/*.test.luau`.

## Shipping
- Branch + PR for every change; merge yourself when the gate passes, then tell Rayyan.
- Never publish live. Rayyan publishes to his account himself.
