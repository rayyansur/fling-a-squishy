# Examples

Reference only; not built by CI. Copy patterns from here into `game/`, `art/models/` and
`tests/cloud/` of a game repo.

- `lantern-plaza/`: a Blender lantern (curved lathe post, joined parts, materials), placed with
  `ctx.Assets:place`, tagged and switched on/off by a server module, a client hint, and a cloud test.
  Its `art/assets.lock.json` shows what CI writes after uploading a model.
