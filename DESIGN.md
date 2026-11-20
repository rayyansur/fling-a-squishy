# <Game name>: design brief

Claude fills this in from Rayyan's idea before building. Keep it current as the game changes.

## The idea (Rayyan's words)
>

## Pitch
One sentence a player would read on the game page.

## Art direction
Rayyan's call: style, palette, mood, references. (Ask if not given.)

## Players
Max players + why.

## Core loop
What the player does every 30 seconds, every 5 minutes, every session.

## Progression
Levels, currencies, unlocks, rebirths, and how long each step takes.

## Monetization (medium, see GUIDELINES)
Every row goes into `game/monetization.json` (key = lower_snake_case); CI creates them.

| Key | Item | Type | What it does | Price (R$) |
|---|---|---|---|---|

## Map
Areas, landmarks, Blender models needed.

## UI
Screens and HUD elements.

## Tests
What `tests/cloud/*.test.luau` must prove.

## Build order
1. First playable slice (spawn → core loop → reward)
2. Progression
3. Monetization
4. Polish (models, lighting, effects)

## Open questions / risks
