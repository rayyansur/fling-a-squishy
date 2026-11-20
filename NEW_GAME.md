# New game checklist (Rayyan, ~5 min)

Claude sends this when you start a new game. Do these, then send Claude the repo name and
test place id.

1. **Repo from the template.** On GitHub, open `rayyansur/roblox-pipeline` →
   **Use this template → Create a new repository** → owner `rayyansur`, name = the game,
   **Private**.
2. **Secret + variable** in the new repo: **Settings → Secrets and variables → Actions**
   - Secret `ROBLOX_API_KEY` (same Open Cloud key as before)
   - Variable `ROBLOX_CREATOR_ID` = your Roblox user id
3. **Test place.** In Studio: **File → New → Baseplate → File → Publish to Roblox As…** →
   name it "<Game> (test)", keep it private. Copy its place id (Creator Dashboard → the
   experience → ⋯ → Copy Start Place ID). Then close that Studio window without saving again.
4. **Key access.** Nothing to do while your key covers every experience. If you ever limit it,
   add the new experience with **universe-places** (Write), **Luau execution sessions**
   (Read, Write), **assets** (Read, Write), **game-pass** (Read, Write) and
   **developer-product** (Read, Write).
5. Tell Claude: repo name + test place id. Claude connects the repo and does the rest.

## Going live (when you like the test place)

1. **Live place.** Publish a new baseplate to your account the same way as step 3, named the
   game. Send Claude its place id and universe id (Creator Dashboard → the experience → ⋯).
   Close that Studio window without saving: saving it later would overwrite the real game.
2. Claude adds them to the repo and sends you the publish link.
3. **Publish:** `https://github.com/rayyansur/<game>/actions/workflows/pipeline.yml` →
   **Run workflow** → `main` → tick **publish_live** → green button. Do this again whenever
   Claude says a fix should go live. Claude never publishes live.
4. **Game page** (Claude sends the text and the art):
   - Join while it's Private and check your progress saves when you rejoin.
   - Title, genre and description. If Roblox rejects the text, tell Claude: the filter doesn't
     say which line, so it gets reworded.
   - Icon and 3 thumbnails from `marketing/`, then turn on thumbnail personalization.
   - Optional gameplay video.
   - The questionnaire (declare any paid random item).
   - Check the passes and products are on sale.
   - Set it **Public**.
