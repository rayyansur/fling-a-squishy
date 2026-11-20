# roblox-pipeline: game factory template

Send Claude a game idea. Claude designs it (`DESIGN.md`), builds the map and scripts, models
the props in Blender, checks everything offline, previews and playtests it in your Studio,
publishes it to a private test place, crash-tests it inside a real Roblox server, merges, and
tells you. You playtest and publish to your account when you like it.

```
idea ─► DESIGN.md ─► code + Blender models ─► tools/check.sh ─► Studio sync, screenshots, playtest
     ─► PR ─► CI: upload art → build + checks → publish TEST place → crash test in Roblox
     ─► merge + report ─► you playtest ─► you publish live
```

- **Start a new game:** `NEW_GAME.md` (5 minutes, one repo per game). Going live is at the
  bottom of the same file.
- **How Claude works:** `CLAUDE.md`. **Your rules:** `GUIDELINES.md`. **What we've learnt:** `HANDBOOK.md`.
- **Example game with every piece wired up:** `examples/lantern-plaza/`.

## One-time setup (done)
- Studio MCP server on and connected to the Claude desktop app.
- Studio workbench `~/code/roblox-pipeline-builds/Build.rbxlx` open in Studio.
- Local build server for Studio (LaunchAgent `com.roblox-pipeline.builds`, 127.0.0.1:34872).
- Open Cloud API key with universe-places (Write), Luau execution sessions (Read, Write),
  assets (Read, Write), game-pass (Read, Write), developer-product (Read, Write).

## Layout
| Path | What |
|---|---|
| `pipeline.json` | game name, repo, max players, test/live ids, budgets, Studio views |
| `DESIGN.md` | the game's design brief |
| `game/` | settings, map builders, scripts (Rojo-style), `monetization.json` (passes + products) |
| `kit/` | shared runtime: saves, purchases, safe remotes, store UI (see `kit/README.md`) |
| `art/models/` | Blender models (Python); `art/out/` built FBX; `art/assets.lock.json` uploaded ids |
| `tests/cloud/` | crash tests that run inside a Roblox server |
| `build/`, `kit/`, `tools/`, `.github/` | the pipeline (same in every game) |

## Commands
| Command | What |
|---|---|
| `tools/check.sh` | build `out/Game.rbxlx` + offline checks |
| `python3 tools/art_build.py [name]` | Blender models → FBX + preview |
| `tools/studio_prepare.sh` | export the build for the Studio sync |
| `python3 tools/roblox_cloud.py publish/test/upload-art/sync-products` | Open Cloud (runs in CI) |
