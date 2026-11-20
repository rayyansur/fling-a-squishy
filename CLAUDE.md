# Roblox game factory: how Claude works here

Rayyan sends a game idea or a change in plain words. Claude designs it, builds it, makes
the models, tests it (offline, in his Studio, and inside a real Roblox server), merges it,
and tells him. Read `GUIDELINES.md` before every task; it wins over this file. Then read
`HANDBOOK.md`: what Rayyan always asks for, and the Roblox/Studio/CI traps we've already hit.

This repo is the **template**. Every game gets its own private repo made from it.

---

## A. New game (idea → playable test place)

1. **Design brief.** Turn the idea into `DESIGN.md` (fill in `DESIGN.md` in the new repo):
   core loop, session flow, progression, monetization (per GUIDELINES), max players, map list,
   models list, UI screens, risks. Everything is designed fresh from the idea: no stock genre
   template. **Art style is Rayyan's call**: if the idea doesn't state it, ask him once in a
   single short message (offer 2-3 concrete directions), then continue.
2. **Repo.** Ask Rayyan to do the `NEW_GAME.md` checklist (repo from template, secret,
   variable, test place, API key access) and send the repo name + test place id. While
   waiting, build in a local copy of the template.
3. **Attach + configure.** Attach the repo with push access, clone, then in `pipeline.json` set
   `name`, `repo` (owner/name), `maxPlayers`, `roblox.testPlaceId` + `testUniverseId`
   (ask Rayyan or read them from Studio: `game.PlaceId`, `game.GameId`), and `views`.
4. **Build** with the loop in section B until the whole DESIGN.md is in. First playable slice
   first (spawn → core loop → reward), then progression, then monetization, then polish.
   `HANDBOOK.md` section 0 lists what to build into the first three PRs so the usual feedback
   rounds don't happen.
5. **Hand over.** Merge, then message Rayyan: what's in, Studio screenshots, how to join the
   test place, what to playtest. He publishes to his live account himself.
6. **Going live.** When he sends the live place + universe ids, put them in `pipeline.json`
   (`roblox.livePlaceId`, `roblox.liveUniverseId`), merge, and send him the workflow link to run
   with `publish_live` ticked, plus the game page checklist (`NEW_GAME.md`, `HANDBOOK.md`
   section 12). After any later fix he wants live, send the link again.

## B. The build loop (every idea or change)

1. **Branch.** `git checkout main && git pull && git checkout -b idea/<slug>`.
2. **Code.**
   - Map: `game/map/NN_name.luau` (Lune, helpers in `build/lib/B.luau`; returns `function(B, ctx)`).
   - World/lighting: `game/settings.luau`.
   - Scripts, Rojo-style under `game/src/<Service>/` (`X.server.luau`, `X.client.luau`,
     `X.luau`, `folder/init.server.luau` …). Server logic = ModuleScripts with `start()` under the
     `Server` script; client logic = modules with `start()` under `Client`.
   - Saves, purchases, remotes, store UI: **use the kit** (`kit/README.md`): `Kit.Data`,
     `Kit.Shop`, `Kit.Net`, `Kit.UI`/`Kit.StoreUI`, `Kit.Odds`. Never hand-roll DataStores,
     `ProcessReceipt` or unvalidated remotes.
   - Passes + products in `game/monetization.json` (CI creates them and fills the ids).
     Tunables, save defaults (`Config.Data`) and theme (`Config.Theme`) in
     `game/src/ReplicatedStorage/Shared/Config.luau`.
   - Tests: `tests/cloud/<feature>.test.luau` for every feature (they run in a real server).
3. **Models.** Anything curved or detailed is a Blender model: `art/models/<name>.py`
   (`build(bpy, kit)`, 1 unit = 1 stud, base at Z=0; see `examples/lantern-plaza`).
   `python3 tools/art_build.py <name>` → open `out/art/<name>.png` (four angles + a 5-stud
   player) and judge every view; iterate until it matches the art direction. Place it with `ctx.Assets:place(parent, "<name>", cframe)`.
   Commit `art/out/<name>.fbx` + `art/out/manifest.json`; CI uploads and fills `art/assets.lock.json`.
   **UI icons** are pictures, never emoji: `art/icons/*.py` → `tools/icon_build.py` → sprite
   one image per icon in `art/images/` (CI uploads them) → `Kit.Icon` (`kit/README.md`).
4. **Offline checks.** `tools/check.sh` green. Never weaken or skip a check.
5. **Studio pass** (Rayyan's Mac). If Studio or the Mac is unreachable, say so and rely on CI.
   - `tools/studio_prepare.sh`; copy every file in `out/studio/` to
     `~/code/roblox-pipeline-builds/studio/`, clearing old `chunk_*.json` first (Claude Code on the
     Mac: plain `cp`; device bridge: stage in `/mnt/user-data/outputs/`, then `device_commit_files`).
   - Claude Code needs the Studio MCP too: `claude mcp add Roblox_Studio --
     /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` (once; new sessions pick it up).
   - Studio MCP `list_roblox_studios` → the workbench place (`Build.rbxlx`). If no place is open,
     reopen it with Studio's menu **File → Recent → Build** (computer use; request access to
     RobloxStudio if needed). Never use Studio menus to save, publish or close places.
   - `execute_luau` (Edit) with the contents of `tools/studio/sync_snippet.luau`: it installs the
     current loader from the build server and syncs the game into the open place.
   - `screen_capture` each `views` entry (and any new angle the change needs). Look properly:
     floating/clipping parts, missing models (pink placeholder = art not uploaded yet), unreadable
     signs, lighting. Fix and resync until it looks right.
   - UI changed? In the playtest, open the HUD and every panel and tab and run the UI audit
     (`return require(game.ReplicatedStorage.PipelineUIAudit)()`, Client) until each says `ok`
     (HANDBOOK section 6).
   - Studio-only limits of the sync (they're fine in the published place): `Lighting.Technology`
     can't be set from Studio scripts.
   - `start_stop_play` → wait `studio.playtestSeconds` → `get_console_output` → also check state
     directly with `execute_luau` in the `Server` and `Client` datamodels → stop. Any error or
     warning from game scripts is a bug; fix before shipping. Use `character_navigation` /
     `user_keyboard_input` to walk the core loop when the change touches it.
6. **Ship.** Commit (clear message), push, open a PR (what changed, checks, Studio findings,
   known limits). GraphQL is blocked here, so use REST:
   `gh api repos/<repo>/pulls -f title=… -f head=<branch> -f base=main -F body=@body.md`. CI: upload art → build + checks → publish TEST place → crash test in
   Roblox. Read failures with
   `gh api repos/<repo>/check-runs/<job id>/annotations` (raw logs aren't reachable). Fix red.
7. **Merge** when CI is green: `gh api -X PUT repos/<repo>/pulls/<n>/merge -f merge_method=squash
   -f commit_message="<title> (#<n>)"` (without it the squash can inherit `[skip ci]`),
   then `git push origin --delete <branch>`. No need to ask. Check CI with
   `gh run list --repo <repo> --branch <branch>` and `gh run view <id> --json jobs`.
8. **Learn.** Add anything new from the round (a trap, a fix, a preference of Rayyan's) to
   the template's `HANDBOOK.md`, written generically.
9. **Tell Rayyan** in one short message: what shipped, PR link, 1-3 screenshots (send the
   images), what to playtest. Mention anything skipped (e.g. Studio unreachable).

## Hard rules
- **Never publish live.** The `publish_live` workflow input is Rayyan's alone; he publishes to his
  account himself.
- Never ask for or handle the Roblox API key; it lives only in GitHub secrets.
- Don't touch other games' repos or the template's `examples/` unless asked.
- Keep `build/`, `kit/`, `tools/`, `.github/` and `tests/cloud/harness.luau` in sync with the
  template; improve them in the template repo (`rayyansur/roblox-pipeline`) first, then copy
  into games.

## Reference
- Working example of every piece (Blender model, tags, server module, client, test):
  `examples/lantern-plaza/`.
- Builder helpers: `build/lib/B.luau` (`part`, `box`, `boxMM`, `vcyl`, `ball`, `beam`, `wedge`,
  `light`, `surface` for signs, `particles`, `prompt`, `rng`, `import` for prebuilt `.rbxm` files).
  Models: `build/lib/Assets.luau`.
- Runtime kit (saves, shop, remotes, UI): `kit/README.md`.
- Tooling: Lune 0.11+, luau-lsp (`tools/install_tools.sh`, Linux or Mac; installs to
  `~/.local/bin`), Blender as `pip install bpy`.
