#!/usr/bin/env python3
"""Roblox Open Cloud helper (Python stdlib only). Used by CI; needs ROBLOX_API_KEY.

  publish     --place-id ID [--file out/Game.rbxlx]
                 publish a place version; prints/outputs `version` and `universe`
  test        --place-id ID [--version N]
                 crash-test inside a real Roblox server (tests/cloud/harness.luau + kit/tests + tests/cloud);
                 exits 1 on any failed test or logged error
  upload-art  --place-id ID [--creator-id USERID]
                 upload changed art/out/*.fbx as Model assets, read back their MeshParts inside
                 a Roblox server, and write art/assets.lock.json; upload changed art/images/*.png
                 (UI icons, sprite sheets) and write art/images.lock.json; prints `changed=true|false`
  sync-products --target test|live
                 create/update the passes + developer products in game/monetization.json in that
                 universe and write their ids to game/monetization.lock.json; prints `changed=...`

Key scopes: universe-places (Write) · universe.place.luau-execution-session (Read, Write) ·
assets (Read, Write) · game-pass (Read, Write) · developer-product (Read, Write).
"""
import argparse, glob, hashlib, json, os, sys, time, uuid, urllib.request, urllib.error

API = "https://apis.roblox.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def die(msg):
    """Exit with an error that also shows up as a GitHub annotation (readable via the API)."""
    msg = str(msg)
    if os.environ.get("GITHUB_ACTIONS"):
        print("::error::" + msg.replace("\n", "%0A")[:4000])
    sys.exit(msg)


def note(msg):
    print(msg)
    if os.environ.get("GITHUB_ACTIONS"):
        print("::notice::" + str(msg).replace("\n", "%0A")[:4000])


def key():
    k = os.environ.get("ROBLOX_API_KEY")
    if not k:
        die("ROBLOX_API_KEY is not set")
    return k


def call(method, url, body=None, ctype="application/json", auth=True, retries=6, hint=""):
    headers = {"Content-Type": ctype} if body is not None else {}
    if auth:
        headers["x-api-key"] = key()
    data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
    for attempt in range(retries):
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                wait = int(e.headers.get("Retry-After") or 0) or 6 * (attempt + 1)
                print(f"  HTTP {e.code}, retrying in {wait}s")
                time.sleep(wait)
                continue
            # 409 "Save failed. Server is busy ... try again in a couple minutes": a place upload
            # that collides with another save (often the place open in Studio). Wait it out.
            if e.code == 409 and "busy" in msg.lower() and attempt < retries - 1:
                wait = 30 * (attempt + 1)
                print(f"  HTTP 409 (Roblox busy saving this place), retrying in {wait}s")
                time.sleep(wait)
                continue
            extra = f"\n{hint}" if hint and e.code in (401, 403) else ""
            die(f"{method} {url} -> HTTP {e.code}: {msg}{extra}")
        except urllib.error.URLError as e:
            if attempt < retries - 1:
                time.sleep(5)
                continue
            die(f"{method} {url} -> {e}")


def output(**kv):
    out = os.environ.get("GITHUB_OUTPUT")
    for k, v in kv.items():
        print(f"{k}={v}")
    if out:
        with open(out, "a") as f:
            for k, v in kv.items():
                f.write(f"{k}={v}\n")


def pipeline_cfg():
    return json.load(open(os.path.join(ROOT, "pipeline.json"))).get("roblox", {})


def target(args):
    """--target test|live picks ids from pipeline.json; --place-id overrides.

    Safety for repos made from the template: if pipeline.json's "repo" isn't this repo, its
    place ids belong to another game, so cloud steps are skipped (test) or refused (live)."""
    cfg = pipeline_cfg()
    which = getattr(args, "target", "test") or "test"
    owner = json.load(open(os.path.join(ROOT, "pipeline.json"))).get("repo")
    here = os.environ.get("GITHUB_REPOSITORY")
    if owner and here and owner.lower() != here.lower():
        msg = (f"pipeline.json belongs to {owner}, not {here}: set \"repo\" and the roblox ids "
               f"for this game (see NEW_GAME.md)")
        if which == "live":
            die(msg)
        note("skipped: " + msg)
        output(skipped="true")
        sys.exit(0)
    place = getattr(args, "place_id", None) or cfg.get(f"{which}PlaceId")
    if not place:
        if which == "live":
            die("no live place id: set roblox.livePlaceId in pipeline.json")
        note(f"skipped: no {which} place yet (roblox.{which}PlaceId in pipeline.json)")
        output(skipped="true")
        sys.exit(0)
    uni = cfg.get(f"{which}UniverseId") if place == cfg.get(f"{which}PlaceId") else None
    return str(place), (str(uni) if uni else None)


_universe_cache = {}


def universe_for(place_id):
    if os.environ.get("UNIVERSE_ID"):
        return os.environ["UNIVERSE_ID"]
    if place_id in _universe_cache:
        return _universe_cache[place_id]
    cfg = pipeline_cfg()
    for which in ("test", "live"):
        if str(cfg.get(f"{which}PlaceId")) == str(place_id) and cfg.get(f"{which}UniverseId"):
            return str(cfg[f"{which}UniverseId"])
    uni = str(call("GET", f"{API}/universes/v1/places/{place_id}/universe", auth=False)["universeId"])
    _universe_cache[place_id] = uni
    return uni


# ------------------------------------------------------------------ publish
def publish(args):
    args.place_id, _ = target(args)
    uni = universe_for(args.place_id)
    path = os.path.join(ROOT, args.file)
    ctype = "application/xml" if path.endswith(".rbxlx") else "application/octet-stream"
    body = open(path, "rb").read()
    res = call("POST", f"{API}/universes/v1/{uni}/places/{args.place_id}/versions?versionType=Published", body, ctype)
    print(f"published place {args.place_id} (universe {uni}) → version {res['versionNumber']}")
    output(version=res["versionNumber"], universe=uni)
    return res["versionNumber"]


# ------------------------------------------------------------------ luau execution
def run_luau(place_id, script, version=None, timeout=240):
    uni = universe_for(place_id)
    base = f"{API}/cloud/v2/universes/{uni}/places/{place_id}"
    url = f"{base}/versions/{version}/luau-execution-session-tasks" if version else f"{base}/luau-execution-session-tasks"
    task = call("POST", url, {"script": script, "timeout": f"{timeout}s"})
    path = task["path"]
    state = task.get("state")
    deadline = time.time() + timeout + 180
    while state not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() > deadline:
            die("timed out waiting for the Luau task")
        time.sleep(3)
        task = call("GET", f"{API}/cloud/v2/{path}")
        state = task.get("state")
    logs = call("GET", f"{API}/cloud/v2/{path}/logs")
    lines = []
    for page in logs.get("luauExecutionSessionTaskLogs", []):
        lines.extend(page.get("messages", []))
    return task, lines


def render_test(expect_product_ids=False):
    """The single Luau script the crash test runs: harness + kit/tests + tests/cloud suites."""
    harness = open(os.path.join(ROOT, "tests/cloud/harness.luau"), encoding="utf-8").read()
    suites = []
    files = sorted(glob.glob(os.path.join(ROOT, "kit/tests/*.test.luau"))) + sorted(glob.glob(os.path.join(ROOT, "tests/cloud/*.test.luau")))
    for f in files:
        name = os.path.basename(f)[: -len(".test.luau")]
        src = open(f, encoding="utf-8").read()
        suites.append(f'GAME_TESTS[{json.dumps(name)}] = (function()\n{src}\nend)()')
    script = harness.replace("--@@GAME_TESTS@@", "\n" + "\n".join(suites) + "\n")
    opts = {"expectProductIds": bool(expect_product_ids)}
    return script.replace("{} --@@OPTIONS@@", "{ " + ", ".join(f"{k} = {str(v).lower()}" for k, v in opts.items()) + " }")


def run_test(args):
    args.place_id, _ = target(args)
    script = render_test(getattr(args, "expect_product_ids", False))
    task, logs = run_luau(args.place_id, script, args.version, args.timeout)
    for line in logs:
        print("  log |", line)
    if task.get("state") != "COMPLETE":
        die(f"Luau task {task.get('state')}: {json.dumps(task.get('error'))}\n" + "\n".join(logs[-15:]))
    res = (task.get("output", {}).get("results") or [{}])[0] or {}
    for line in res.get("info", []):
        print("  info |", line)
    failed, errors = res.get("failed") or [], res.get("errors") or []
    for f in failed:
        print("FAIL  ", f)
    for e in errors:
        print("ERROR ", e)
    if failed or errors:
        die(f"CRASH TEST FAILED: {len(failed)} failed, {len(errors)} errors logged\n" + "\n".join((failed + errors)[:20]))
    note(f"CRASH TEST PASSED: {res.get('passed', 0)} checks · " + " · ".join(res.get("info", [])))


# ------------------------------------------------------------------ art upload
PROBE = r"""
local InsertService = game:GetService("InsertService")
local ids = %s
local out = {}
for name, id in ids do
	local ok, model = pcall(function() return InsertService:LoadAsset(tonumber(id)) end)
	if not ok then
		out[name] = { error = tostring(model) }
		continue
	end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then table.insert(parts, d) end
	end
	-- pivot = bottom-center of the whole model's bounding box
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local h = p.Size / 2
		for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
			local w = p.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
			lo = lo:Min(w); hi = hi:Max(w)
		end end end
	end
	local pivot = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local list = {}
	for _, p in parts do
		table.insert(list, {
			name = p.Name,
			meshId = p.MeshId,
			textureId = p.TextureID,
			size = { p.Size.X, p.Size.Y, p.Size.Z },
			offset = { (pivot:ToObjectSpace(p.CFrame)):GetComponents() },
		})
	end
	out[name] = { parts = list, bounds = { hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z } }
	model:Destroy()
end
return out
"""


def multipart(fields, file_field=None, filename=None, file_bytes=None, file_type=None):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    if file_field:
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{filename}"\r\n'
                     f"Content-Type: {file_type}\r\n\r\n".encode() + file_bytes + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def upload_fbx(name, path, creator_id, asset_id=None):
    request = {"assetType": "Model", "displayName": f"art_{name}"[:50], "description": "roblox-pipeline art",
               "creationContext": {"creator": {"userId": str(creator_id)}}}
    if asset_id:
        request["assetId"] = str(asset_id)
    body, ctype = multipart({"request": json.dumps(request)}, "fileContent", f"{name}.fbx", open(path, "rb").read(), "model/fbx")
    if asset_id:
        op = call("PATCH", f"{API}/assets/v1/assets/{asset_id}", body, ctype)
    else:
        op = call("POST", f"{API}/assets/v1/assets", body, ctype)
    op_path = op.get("path") or op.get("operationId")
    if not op_path.startswith("operations/"):
        op_path = "operations/" + op_path
    for _ in range(90):
        res = call("GET", f"{API}/assets/v1/{op_path}")
        if res.get("done"):
            if "response" not in res:
                die(f"upload of {name} failed: {json.dumps(res)}")
            r = res["response"]
            state = (r.get("moderationResult") or {}).get("moderationState")
            print(f"  {name}: asset {r['assetId']} ({state or 'no moderation info'})")
            return str(r["assetId"])
        time.sleep(3)
    die(f"upload of {name} timed out")


def upload_art(args):
    args.place_id, _ = target(args)
    creator = args.creator_id or os.environ.get("ROBLOX_CREATOR_ID")
    if not creator:
        die("set ROBLOX_CREATOR_ID (your Roblox user id)")
    models = upload_models(args, creator)
    images = upload_images(args, creator)
    output(changed="true" if models or images else "false")


def upload_models(args, creator):
    manifest_path = os.path.join(ROOT, "art/out/manifest.json")
    lock_path = os.path.join(ROOT, "art/assets.lock.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    lock = json.load(open(lock_path)) if os.path.exists(lock_path) else {}
    todo = {}
    for name, m in manifest.items():
        fbx = os.path.join(ROOT, "art/out", name + ".fbx")
        if not os.path.exists(fbx):
            continue
        e = lock.get(name, {})
        if e.get("sha256") != m["sha256"] or not e.get("parts"):
            todo[name] = fbx
    removed = [n for n in lock if n not in manifest]
    for n in removed:
        del lock[n]
    if not todo:
        print("art: no models to upload")
        if removed:
            json.dump(lock, open(lock_path, "w"), indent=1, sort_keys=True)
        return bool(removed)
    ids = {}
    for name, fbx in todo.items():
        # FBX content can be updated in place, so reuse the asset when we have one
        ids[name] = upload_fbx(name, fbx, creator, lock.get(name, {}).get("assetId"))
    # meshes need a moment after upload before servers can load them
    probe = PROBE % ("{" + ", ".join(f"[{json.dumps(n)}] = {json.dumps(i)}" for n, i in ids.items()) + "}")
    info = {}
    for attempt in range(6):
        task, logs = run_luau(args.place_id, probe, None, 120)
        if task.get("state") != "COMPLETE":
            die("probe failed: " + json.dumps(task.get("error")))
        info = (task.get("output", {}).get("results") or [{}])[0] or {}
        pending = [n for n in ids if not (info.get(n) or {}).get("parts")]
        if not pending:
            break
        print(f"  waiting for Roblox to process: {pending} ({[info.get(n) for n in pending]})")
        time.sleep(20)
    for name, asset_id in ids.items():
        got = info.get(name) or {}
        if not got.get("parts"):
            die(f"{name}: uploaded as {asset_id} but its meshes could not be loaded: {got}")
        mparts = {p["name"]: p for p in manifest[name].get("parts", [])}
        for p in got["parts"]:
            src = mparts.get(p["name"].split(".")[0]) or {}
            if src.get("color"):
                p["color"] = src["color"]
            if src.get("material"):
                p["material"] = src["material"]
        lock[name] = {"sha256": manifest[name]["sha256"], "assetId": asset_id, "bounds": got["bounds"], "parts": got["parts"]}
        print(f"  {name}: {len(got['parts'])} mesh parts recorded")
    json.dump(lock, open(lock_path, "w"), indent=1, sort_keys=True)
    return True


# ------------------------------------------------------------------ images (UI icons, one per file)
IMAGE_PROBE = r"""
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")
local ids = %s
local out = {}
for name, id in ids do
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(tonumber(id), Enum.InfoType.Asset) end)
	if not ok then
		out[name] = { error = tostring(info) }
		continue
	end
	if info.AssetTypeId == 1 then -- an Image: usable as is
		out[name] = { imageId = tostring(id) }
		continue
	end
	-- a Decal: its image is the Texture of the Decal inside
	local ok2, model = pcall(function() return InsertService:LoadAsset(tonumber(id)) end)
	if not ok2 then
		out[name] = { error = tostring(model), type = info.AssetTypeId }
		continue
	end
	local d = model:FindFirstChildWhichIsA("Decal", true)
	out[name] = { imageId = d and string.match(d.Texture, "(%%d+)$") or nil, type = info.AssetTypeId }
	model:Destroy()
end
return out
"""


def upload_image_asset(name, path, creator_id):
    data = open(path, "rb").read()
    last = None
    for asset_type in ("Image", "Decal"):
        request = {"assetType": asset_type, "displayName": f"img_{name}"[:50], "description": "roblox-pipeline image",
                   "creationContext": {"creator": {"userId": str(creator_id)}}}
        body, ctype = multipart({"request": json.dumps(request)}, "fileContent", os.path.basename(path), data, "image/png")
        try:
            op = call("POST", f"{API}/assets/v1/assets", body, ctype, retries=2)
        except SystemExit as e:  # an older API without the Image type: fall back to Decal
            last = e
            continue
        op_path = op.get("path") or op.get("operationId")
        if not op_path.startswith("operations/"):
            op_path = "operations/" + op_path
        for _ in range(90):
            res = call("GET", f"{API}/assets/v1/{op_path}")
            if res.get("done"):
                if "response" not in res:
                    die(f"upload of image {name} failed: {json.dumps(res)}")
                r = res["response"]
                state = (r.get("moderationResult") or {}).get("moderationState")
                print(f"  {name}: {asset_type} asset {r['assetId']} ({state or 'no moderation info'})")
                return str(r["assetId"])
            time.sleep(3)
        die(f"upload of image {name} timed out")
    die(f"upload of image {name} failed: {last}")


IMAGE_BATCH = 20  # images uploaded, probed and written to the lock together


def upload_images(args, creator):
    """art/images/<name>.png -> art/images.lock.json { name: { sha256, assetId, imageId } }.
    (A sprite sheet's <name>.json, with each sprite's rect, is read by the build, not uploaded.)
    Uploads go in batches of IMAGE_BATCH and the lock is written after each, so a big first
    upload (one image per UI icon) that fails part way keeps what it finished: the job still
    commits the partial lock (with a warning) and the next push uploads the rest."""
    folder = os.path.join(ROOT, "art/images")
    lock_path = os.path.join(ROOT, "art/images.lock.json")
    lock = json.load(open(lock_path)) if os.path.exists(lock_path) else {}
    pngs = {os.path.basename(f)[:-4]: f for f in sorted(glob.glob(os.path.join(folder, "*.png")))}
    changed = False
    for n in [n for n in lock if n not in pngs]:
        del lock[n]
        changed = True
    todo = {}
    for name, f in pngs.items():
        sha = hashlib.sha256(open(f, "rb").read()).hexdigest()
        if lock.get(name, {}).get("sha256") != sha or not lock[name].get("imageId"):
            todo[name] = (f, sha)
    if not todo:
        print("art: no images to upload")
        if changed:
            json.dump(lock, open(lock_path, "w"), indent=1, sort_keys=True)
        return changed
    print(f"art: uploading {len(todo)} image(s)")
    names = list(todo)
    done = 0
    for b in range(0, len(names), IMAGE_BATCH):
        batch = names[b:b + IMAGE_BATCH]
        try:
            ids = {name: upload_image_asset(name, todo[name][0], creator) for name in batch}
            info = probe_images(args, ids)
        except SystemExit as e:
            if done == 0:
                raise
            print(f"::warning::image upload stopped after {done} of {len(todo)} images ({e}); "
                  "the rest upload on the next push" if os.environ.get("GITHUB_ACTIONS") else
                  f"image upload stopped after {done} of {len(todo)} images ({e})")
            return True
        for name, asset_id in ids.items():
            got = info.get(name) or {}
            if not got.get("imageId"):
                die(f"image {name}: uploaded as {asset_id} but no image id came back: {got}")
            lock[name] = {"sha256": todo[name][1], "assetId": asset_id, "imageId": got["imageId"]}
            print(f"  {name}: image rbxassetid://{got['imageId']}")
        done += len(batch)
        json.dump(lock, open(lock_path, "w"), indent=1, sort_keys=True)
    return True


def probe_images(args, ids):
    """Ask a Roblox server which image id each uploaded asset gives (a Decal wraps its image)."""
    probe = IMAGE_PROBE % ("{" + ", ".join(f"[{json.dumps(n)}] = {json.dumps(i)}" for n, i in ids.items()) + "}")
    info = {}
    for attempt in range(6):
        task, logs = run_luau(args.place_id, probe, None, 120)
        if task.get("state") != "COMPLETE":
            die("image probe failed: " + json.dumps(task.get("error")))
        info = (task.get("output", {}).get("results") or [{}])[0] or {}
        pending = [n for n in ids if not (info.get(n) or {}).get("imageId")]
        if not pending:
            break
        print(f"  waiting for Roblox to process images: {pending} ({[info.get(n) for n in pending]})")
        time.sleep(20)
    return info


# ------------------------------------------------------------------ passes + developer products
# kind -> (api base, collection, id field, list field)
MONETIZATION = {
    "passes": ("game-passes/v1", "game-passes", "gamePassId", "gamePasses"),
    "products": ("developer-products/v2", "developer-products", "productId", "developerProducts"),
}
SCOPE_HINT = ("The Open Cloud key needs game-pass (Read, Write) and developer-product (Read, Write) "
              "for this experience: Creator Dashboard → Open Cloud → API Keys (see NEW_GAME.md).")


def list_existing(uni, kind):
    base, coll, idf, listf = MONETIZATION[kind]
    out, token = {}, ""
    while True:
        url = f"{API}/{base}/universes/{uni}/{coll}/creator?pageSize=50" + (f"&pageToken={token}" if token else "")
        res = call("GET", url, hint=SCOPE_HINT)
        for it in res.get(listf) or []:
            out[it.get("name")] = it.get(idf)
        token = res.get("nextPageToken")
        if not token:
            return out


def write_item(uni, kind, item, item_id=None, for_sale=True):
    base, coll, idf, _ = MONETIZATION[kind]
    fields = {"isForSale": "true" if for_sale else "false"}
    if item is not None:
        fields.update(name=item["name"], description=item.get("description") or "", price=str(int(item["price"])))
    icon = item and item.get("icon")
    if icon:
        data = open(os.path.join(ROOT, icon), "rb").read()
        ctype_img = "image/png" if icon.lower().endswith(".png") else "image/jpeg"
        body, ctype = multipart(fields, "imageFile", os.path.basename(icon), data, ctype_img)
    else:
        body, ctype = multipart(fields)
    if item_id:
        call("PATCH", f"{API}/{base}/universes/{uni}/{coll}/{item_id}", body, ctype, hint=SCOPE_HINT)
        return str(item_id)
    res = call("POST", f"{API}/{base}/universes/{uni}/{coll}", body, ctype, hint=SCOPE_HINT)
    return str(res[idf])


def item_hash(item):
    h = hashlib.sha256(json.dumps(item, sort_keys=True).encode())
    if item.get("icon"):
        h.update(open(os.path.join(ROOT, item["icon"]), "rb").read())
    return h.hexdigest()[:16]


def sync_products(args):
    args.place_id, _ = target(args)
    uni = universe_for(args.place_id)
    spec_path = os.path.join(ROOT, "game/monetization.json")
    lock_path = os.path.join(ROOT, "game/monetization.lock.json")
    spec = json.load(open(spec_path)) if os.path.exists(spec_path) else {}
    lock = json.load(open(lock_path)) if os.path.exists(lock_path) else {}
    mine = lock.setdefault(uni, {})
    changed = False
    for kind in MONETIZATION:
        items = spec.get(kind) or {}
        have = mine.setdefault(kind, {})
        existing = None
        for key, item in sorted(items.items()):
            h = item_hash(item)
            entry = have.get(key)
            if entry and entry.get("hash") == h:
                continue
            item_id = entry and entry.get("id")
            if not item_id:
                # recover ids after a lost lock: Roblox names are unique per universe
                existing = existing if existing is not None else list_existing(uni, kind)
                item_id = existing.get(item["name"])
            new_id = write_item(uni, kind, item, item_id)
            print(f"  {kind}.{key}: {'updated' if item_id else 'created'} {new_id} ({item['name']}, R${item['price']})")
            have[key] = {"id": int(new_id), "hash": h}
            changed = True
        for key in sorted(set(have) - set(items)):
            # Roblox can't delete passes/products: take removed ones off sale
            write_item(uni, kind, None, have[key]["id"], for_sale=False)
            print(f"  {kind}.{key}: removed from monetization.json, taken off sale ({have[key]['id']})")
            del have[key]
            changed = True
    if not any(mine.values()):
        del lock[uni]
    if changed:
        with open(lock_path, "w") as f:
            json.dump(lock, f, indent=1, sort_keys=True)
            f.write("\n")
    else:
        print("products: nothing to sync")
    output(changed="true" if changed else "false")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("publish")
    a.add_argument("--target", choices=["test", "live"], default="test")
    a.add_argument("--place-id")
    a.add_argument("--file", default="out/Game.rbxlx")
    b = sub.add_parser("test")
    b.add_argument("--target", choices=["test", "live"], default="test")
    b.add_argument("--place-id")
    b.add_argument("--version")
    b.add_argument("--timeout", type=int, default=240)
    b.add_argument("--expect-product-ids", action="store_true",
                   help="fail if a pass/product has no id in this universe (push runs, after sync-products)")
    c = sub.add_parser("upload-art")
    c.add_argument("--target", choices=["test", "live"], default="test")
    c.add_argument("--place-id")
    c.add_argument("--creator-id")
    r = sub.add_parser("render-test", help="write the crash-test script (for offline syntax checks)")
    r.add_argument("--out", default="out/cloud_test.luau")
    d = sub.add_parser("sync-products")
    d.add_argument("--target", choices=["test", "live"], default="test")
    d.add_argument("--place-id")
    args = p.parse_args()
    if args.cmd == "render-test":
        with open(os.path.join(ROOT, args.out), "w", encoding="utf-8") as f:
            f.write(render_test(True))
        return
    {"publish": publish, "test": run_test, "upload-art": upload_art, "sync-products": sync_products}[args.cmd](args)


if __name__ == "__main__":
    main()
