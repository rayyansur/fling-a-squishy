#!/usr/bin/env python3
"""Render the game's UI icons with headless Blender, one image per icon.

Icons are tiny 3D scenes, so every button, card and toast gets a picture in the game's own
style instead of an emoji. Each art/icons/<group>.py registers icons with the `icon` decorator:

    from icon_kit import icon            # (art/icons is on the path)

    @icon("coin", view=(18, -20))        # elevation, azimuth in degrees (default 22, -28)
    def coin(bpy, kit):
        gold = kit.mat("gold", "#f2c230", rough=0.3, metal=0.6)
        kit.cylinder("Coin", 1, 0.25, 0, mat=gold, bevel=0.06)

Builders use the same `kit` as art/models (tools/art_build.py Kit). Scale doesn't matter: the
camera frames whatever was built. Outputs:
  out/icons/<name>.png              one icon (256 px, outlined, transparent)
  out/icons/_contact.png            every icon on one sheet, to look at
  art/images/<name>.png             one image per icon (committed; CI uploads each changed one and
                                    the build turns them into Kit.Images, shown with Kit.Icon.set/new).
                                    Not sprite sheets: rect crops break on real Android/PS5 devices.
  art/images/_icons.json            which art/images are icons (so removed ones get deleted)

usage: <blender python> tools/icon_build.py [names...] [--pack-only] [--samples N]
       <blender python> tools/icon_build.py names... --size 512   big single icons in out/icons/512/
                                                                 (game pass art), no sheets
Style knobs (pipeline.json → "icons"): outline (hex), outlineWidth (px at 256), size (px, 256).
"""
import importlib.util, json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "art", "icons")
OUT = os.path.join(ROOT, "out", "icons")
SHEETS = os.path.join(ROOT, "art", "images")
RENDER = 256

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ICONS)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from PIL import Image, ImageChops, ImageFilter  # noqa: E402

import art_build as art  # noqa: E402

REGISTRY = {}


class _IconKit:
    """`from icon_kit import icon` in icon files resolves here."""

    @staticmethod
    def icon(name, view=(22, -28), pad=0.08, light=1.0):
        def wrap(fn):
            REGISTRY[name] = {"fn": fn, "view": view, "pad": pad, "light": light, "file": fn.__module__}
            return fn
        return wrap


sys.modules["icon_kit"] = _IconKit


def style():
    cfg = json.load(open(os.path.join(ROOT, "pipeline.json"))).get("icons", {})
    hexc = cfg.get("outline", "#40281c")
    return {
        "outline": tuple(int(hexc[i:i + 2], 16) for i in (1, 3, 5)),
        "width": int(cfg.get("outlineWidth", 9)),
        "size": int(cfg.get("size", 256)),
    }


def load_all():
    for f in sorted(os.listdir(ICONS)):
        if f.endswith(".py") and not f.startswith("_") and f != "icon_kit.py":
            spec = importlib.util.spec_from_file_location(f[:-3], os.path.join(ICONS, f))
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)


def setup_render(samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL" if sys.platform == "darwin" else "CUDA"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:
        scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = RENDER
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (1, 0.97, 0.92, 1)
    bg.inputs[1].default_value = 0.5
    scene.world = world


def frame(entry):
    """Orthographic camera at (elevation, azimuth), fitted to the built objects."""
    elev, azim = (math.radians(a) for a in entry["view"])
    lo, hi = art.bounds()
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.01)
    d = Vector((math.sin(azim) * math.cos(elev), -math.cos(azim) * math.cos(elev), math.sin(elev)))
    bpy.ops.object.camera_add(location=center + d * radius * 6)
    cam = bpy.context.active_object
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.type = "ORTHO"
    cam.data.clip_end = radius * 20
    bpy.context.scene.camera = cam
    bpy.context.view_layer.update()
    # fit: project every vertex into camera space
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        dg = bpy.context.evaluated_depsgraph_get()
        me = o.evaluated_get(dg).to_mesh()
        for v in me.vertices:
            p = inv @ (o.matrix_world @ v.co)
            xs.append(p.x)
            ys.append(p.y)
        o.evaluated_get(dg).to_mesh_clear()
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    cam.data.ortho_scale = span * (1 + 2 * entry["pad"]) + 1e-4
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    # lights: warm key from the top left, cool-ish rim from behind, soft fill
    k = entry["light"]
    for name, rot, energy, color in (
        ("Key", (math.radians(50), 0, math.radians(-40)), 3.2 * k, (1, 0.96, 0.9)),
        ("Rim", (math.radians(-60), 0, math.radians(160)), 3.0 * k, (1, 0.93, 0.85)),
        ("Fill", (math.radians(70), 0, math.radians(60)), 1.2 * k, (0.92, 0.95, 1)),
    ):
        bpy.ops.object.light_add(type="SUN", rotation=rot)
        sun = bpy.context.active_object
        sun.name = name
        sun.data.energy = energy
        sun.data.color = color
        sun.data.angle = math.radians(25)


def outline(path, st):
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    solid = a.point(lambda v: 255 if v > 90 else 0)
    w = max(1, round(st["width"] * RENDER / 256))
    grown = solid.filter(ImageFilter.MaxFilter(2 * (w // 2) + 1))
    if w > 5:
        grown = grown.filter(ImageFilter.MaxFilter(2 * ((w - w // 2) // 2) + 1))
    grown = grown.filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", im.size, (20, 12, 8, 0))
    shadow.putalpha(grown.point(lambda v: v * 0.35))
    out.alpha_composite(shadow, (0, round(5 * RENDER / 256)))
    ol = Image.new("RGBA", im.size, st["outline"] + (0,))
    ol.putalpha(grown)
    out.alpha_composite(ol)
    out.alpha_composite(im)
    # trim to fit the cell with the outline intact
    box = out.getbbox()
    if box:
        out = out.crop(box)
    side = max(out.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(out, ((side - out.width) // 2, (side - out.height) // 2))
    sq = sq.resize((RENDER, RENDER), Image.LANCZOS)
    sq.save(path)


def render(names, samples, st):
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        entry = REGISTRY[name]
        art.reset()
        setup_render(samples)
        kit = art.Kit(bpy)
        entry["fn"](bpy, kit)
        frame(entry)
        path = os.path.join(OUT, name + ".png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        outline(path, st)
        print(f"icon {name} -> {os.path.relpath(path, ROOT)}")


def pack(st):
    """One image per icon: art/images/<name>.png (`size` px, default 256). No sprite sheets:
    ImageRectOffset/ImageRectSize crops are wrong on some real devices (Android phones, PS5)
    even though Studio shows them right, so every icon showed a neighbour's picture there.
    _icons.json lists the icons, so a later pack can delete the ones that were removed."""
    size = st["size"]
    names = sorted(REGISTRY)
    missing = [n for n in names if not os.path.exists(os.path.join(OUT, n + ".png"))]
    if missing:
        sys.exit(f"render these icons first: {missing}")
    os.makedirs(SHEETS, exist_ok=True)
    listing = os.path.join(SHEETS, "_icons.json")
    before = set(json.load(open(listing))) if os.path.exists(listing) else set()
    # an image that isn't an icon (a logo, a pass picture) must not share an icon's name
    for n in names:
        p = os.path.join(SHEETS, n + ".png")
        if before and n not in before and os.path.exists(p):
            sys.exit(f"art/images/{n}.png isn't an icon: rename the icon or the image")
    # the old sprite sheets, and icons that were removed
    for f in os.listdir(SHEETS):
        if f.startswith("icons") and f[5:6].isdigit() and (f.endswith(".png") or f.endswith(".json")):
            os.remove(os.path.join(SHEETS, f))
    for n in before - set(names):
        if os.path.exists(os.path.join(SHEETS, n + ".png")):
            os.remove(os.path.join(SHEETS, n + ".png"))
    cell = 128
    per_row = 8
    contact = Image.new("RGBA", (per_row * cell, ((len(names) + per_row - 1) // per_row) * cell), (236, 222, 200, 255))
    wrote = 0
    for j, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n + ".png")).convert("RGBA")
        if im.size != (size, size):
            im = im.resize((size, size), Image.LANCZOS)
        dest = os.path.join(SHEETS, n + ".png")
        tmp = dest + ".tmp"
        im.save(tmp, format="PNG", optimize=True)
        # keep the file (and its upload) when the picture didn't change
        if os.path.exists(dest) and open(dest, "rb").read() == open(tmp, "rb").read():
            os.remove(tmp)
        else:
            os.replace(tmp, dest)
            wrote += 1
        contact.alpha_composite(im.resize((cell, cell), Image.LANCZOS), ((j % per_row) * cell, (j // per_row) * cell))
    with open(listing, "w") as f:
        json.dump(names, f, indent=1)
    contact.save(os.path.join(OUT, "_contact.png"))
    print(f"icons: {len(names)} in art/images ({wrote} new or changed)")
    print("contact sheet -> out/icons/_contact.png")


def main():
    global RENDER, OUT
    args = sys.argv[1:]
    samples = 48
    if "--samples" in args:
        samples = int(args[args.index("--samples") + 1])
    big = "--size" in args
    if big:
        RENDER = int(args[args.index("--size") + 1])
        OUT = os.path.join(OUT, str(RENDER))
    names = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] not in ("--samples", "--size"))]
    load_all()
    st = style()
    unknown = [n for n in names if n not in REGISTRY]
    if unknown:
        sys.exit(f"no such icons: {unknown}")
    if "--pack-only" not in args:
        render(names or sorted(REGISTRY), samples, st)
    if big:
        return
    pack(st)


if __name__ == "__main__":
    main()
