#!/usr/bin/env python3
"""Build every art/models/<name>.py with headless Blender (pip package `bpy`).

Each model script defines `build(bpy, kit)` and creates objects in an empty scene.
Units are studs (1 Blender unit = 1 stud); put the model's base at Z=0, centered on X/Y.

Outputs per model:
  art/out/<name>.fbx         uploaded to Roblox by CI (committed)
  art/out/manifest.json      bounding size per model (committed; used for placeholders + unit fix)
  out/art/<name>.png         preview sheet: front 3/4, front, side, back 3/4, with a 5-stud
                             player for scale (Cycles, CPU). Look at all four views.

usage: python3 tools/art_build.py [names...] [--no-render]
"""
import hashlib, importlib.util, json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "art", "models")
OUT = os.path.join(ROOT, "art", "out")
PREVIEWS = os.path.join(ROOT, "out", "art")
MAX_TRIS = 10000

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402


class Kit:
    """Small helpers so model scripts stay short."""

    def __init__(self, bpy):
        self.bpy = bpy
        self._mats = {}

    def mat(self, name, color, rough=0.6, metal=0.0, emit=0.0):
        if name in self._mats:
            return self._mats[name]
        m = self.bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
        bsdf.inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emit:
            bsdf.inputs["Emission Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1)
            bsdf.inputs["Emission Strength"].default_value = emit
        m["roblox_color"] = color
        self._mats[name] = m
        return m

    def finish(self, obj, mat=None, bevel=0.0, segments=2, smooth=True, name=None):
        if name:
            obj.name = name
        if mat is not None:
            obj.data.materials.clear()
            obj.data.materials.append(mat)
        if bevel > 0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
        if smooth:
            for p in obj.data.polygons:
                p.use_smooth = True
        return obj

    def cylinder(self, name, radius, depth, z, verts=32, mat=None, bevel=0.0, x=0, y=0):
        self.bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=(x, y, z + depth / 2))
        return self.finish(self.bpy.context.active_object, mat, bevel, name=name)

    def cone(self, name, r1, r2, depth, z, verts=32, mat=None, bevel=0.0):
        self.bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=(0, 0, z + depth / 2))
        return self.finish(self.bpy.context.active_object, mat, bevel, name=name)

    def box(self, name, sx, sy, sz, x, y, z, mat=None, bevel=0.0):
        self.bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2))
        o = self.bpy.context.active_object
        o.scale = (sx, sy, sz)
        self.bpy.ops.object.transform_apply(scale=True)
        return self.finish(o, mat, bevel, smooth=False, name=name)

    def sphere(self, name, radius, z, mat=None, segs=32, x=0, y=0):
        self.bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=radius, location=(x, y, z))
        return self.finish(self.bpy.context.active_object, mat, name=name)

    def torus(self, name, major, minor, z, mat=None, x=0, y=0):
        self.bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=(x, y, z))
        return self.finish(self.bpy.context.active_object, mat, name=name)

    def tube(self, name, points, radius, mat=None, closed=False, res=2, steps=6, smooth=True):
        """Sweep a round tube through (x, y, z) points: handles, ladles, brackets, neon.
        smooth=False keeps straight segments between the points (sharp outlines)."""
        bpy = self.bpy
        cu = bpy.data.curves.new(name, "CURVE")
        cu.dimensions = "3D"
        cu.resolution_u = steps
        cu.bevel_depth = radius
        cu.bevel_resolution = res
        cu.use_fill_caps = True
        if smooth:
            sp = cu.splines.new("BEZIER")
            sp.bezier_points.add(len(points) - 1)
            for bp, co in zip(sp.bezier_points, points):
                bp.co = co
                bp.handle_left_type = bp.handle_right_type = "AUTO"
        else:
            sp = cu.splines.new("POLY")
            sp.points.add(len(points) - 1)
            for p, co in zip(sp.points, points):
                p.co = (co[0], co[1], co[2], 1)
        sp.use_cyclic_u = closed
        obj = bpy.data.objects.new(name, cu)
        bpy.context.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
        return self.finish(bpy.context.active_object, mat, name=name)

    def lathe(self, name, profile, mat=None, steps=40):
        """Spin a (radius, z) profile around the Z axis: vases, posts, bowls."""
        mesh = self.bpy.data.meshes.new(name)
        verts, faces = [], []
        n = len(profile)
        for s in range(steps):
            a = 2 * math.pi * s / steps
            for r, z in profile:
                verts.append((r * math.cos(a), r * math.sin(a), z))
        for s in range(steps):
            s2 = (s + 1) % steps
            for i in range(n - 1):
                faces.append((s * n + i, s2 * n + i, s2 * n + i + 1, s * n + i + 1))
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = self.bpy.data.objects.new(name, mesh)
        self.bpy.context.collection.objects.link(obj)
        return self.finish(obj, mat, name=name)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bounds():
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        # real vertices, not bound_box: a rotated object's local box inflates the size (a
        # 6-wide slab turned 45 degrees measured 12), and the size scales the model in Roblox
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


def apply_modifiers():
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)


def join_by_name():
    """Objects named "Cage", "Cage.001", ... become one mesh "Cage" (one MeshPart in Roblox)."""
    groups = {}
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            groups.setdefault(o.name.split(".")[0], []).append(o)
    for base, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = base
        joined.data.name = base
    bpy.ops.object.select_all(action="DESELECT")


# Preview views: (name, yaw degrees around the model from its front, camera height factor).
# Models face Blender -Y, so yaw 0 looks at the front.
# The scale player stands on +X, so the side and back views come from -X to keep it out of the way.
VIEWS = [("front 3/4", -35, 0.45), ("front", 0, 0.2), ("side", -90, 0.2), ("back 3/4", -145, 0.45)]
TILE = 560


def _frame_bounds():
    """Bounds of what you can see: skips "Pin" markers (shared bounding-box helpers)."""
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.name.split(".")[0] == "Pin":
            continue
        # real vertices, not bound_box: a rotated object's local box inflates the size (a
        # 6-wide slab turned 45 degrees measured 12), and the size scales the model in Roblox
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


def _mat(name, rgb, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def _dummy(x, y, z0):
    """A 5-stud blocky player next to the model, for scale (preview only)."""
    m = _mat("dummy", (0.35, 0.42, 0.55))
    for (sx, sy, sz, px, pz) in ((0.9, 0.9, 2.0, -0.5, 0), (0.9, 0.9, 2.0, 0.5, 0), (2.0, 1.0, 2.0, 0, 2.0),
                                 (0.9, 0.9, 2.0, -1.45, 2.0), (0.9, 0.9, 2.0, 1.45, 2.0), (1.1, 1.1, 1.0, 0, 4.0)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x + px, y, z0 + pz + sz / 2))
        o = bpy.context.active_object
        o.scale = (sx, sy, sz)
        o.data.materials.append(m)


def render_preview(path, lo, hi):
    """A 2x2 contact sheet (front 3/4, front, side, back 3/4) in Roblox-like daylight, with a
    5-stud player for scale. Colours use the Standard view transform, close to how Roblox shows them."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = TILE
    scene.render.resolution_y = TILE
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    for o in scene.objects:
        if o.name.split(".")[0] == "Pin":
            o.hide_render = True
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.55, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world
    lo, hi = _frame_bounds()
    center = (lo + hi) / 2
    dims = hi - lo
    _dummy(hi.x + 2.2, center.y, lo.z)
    flo, fhi = Vector((lo.x, lo.y, lo.z)), Vector((hi.x + 3.7, hi.y, max(hi.z, lo.z + 5)))
    fcenter = (flo + fhi) / 2
    size = max((fhi - flo).length, 0.5)
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 0))
    sun = bpy.context.active_object
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(40), 0, math.radians(-30))
    bpy.ops.mesh.primitive_plane_add(size=size * 10, location=(center.x, center.y, lo.z - 0.002))
    bpy.context.active_object.data.materials.append(_mat("floor", (0.55, 0.57, 0.6)))
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.data.lens = 50
    scene.camera = cam
    tiles = []
    base, _ = os.path.splitext(path)
    for i, (label, yaw, up) in enumerate(VIEWS):
        a = math.radians(yaw)
        dist = size * 1.55
        cam.location = (fcenter.x + dist * math.sin(a), fcenter.y - dist * math.cos(a), fcenter.z + dist * up)
        cam.rotation_euler = (fcenter - cam.location).to_track_quat("-Z", "Y").to_euler()
        tile = f"{base}.view{i}.png"
        scene.render.filepath = tile
        bpy.ops.render.render(write_still=True)
        tiles.append((label, tile))
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("  (no Pillow: views left as separate files)")
        return
    sheet = Image.new("RGB", (TILE * 2, TILE * 2))
    for i, (label, tile) in enumerate(tiles):
        im = Image.open(tile).convert("RGB")
        ImageDraw.Draw(im).text((10, 8), label, fill=(255, 255, 255))
        sheet.paste(im, ((i % 2) * TILE, (i // 2) * TILE))
        os.remove(tile)
    ImageDraw.Draw(sheet).text((10, TILE * 2 - 18), f"{dims.x:.1f} x {dims.z:.1f} x {dims.y:.1f} studs (w x h x d)", fill=(255, 255, 255))
    sheet.save(path)


def load_model(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(MODELS, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    do_render = "--no-render" not in sys.argv
    names = args or sorted(f[:-3] for f in os.listdir(MODELS) if f.endswith(".py") and not f.startswith("_"))
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEWS, exist_ok=True)
    manifest_path = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    for name in names:
        reset()
        mod = load_model(name)
        kit = Kit(bpy)
        mod.build(bpy, kit)
        apply_modifiers()
        join_by_name()
        lo, hi = bounds()
        size = [round(hi[i] - lo[i], 4) for i in range(3)]
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        parts = []
        for o in meshes:
            mat = o.data.materials[0] if o.data.materials else None
            parts.append({"name": o.name, "color": mat.get("roblox_color") if mat else None,
                          "material": getattr(mod, "ROBLOX_MATERIALS", {}).get(o.name),
                          "tris": sum(len(p.vertices) - 2 for p in o.data.polygons)})
        fbx = os.path.join(OUT, name + ".fbx")
        # Blender Z-up -> Roblox Y-up handled by the FBX axis settings
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False, object_types={"MESH"},
                                 apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                                 axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                                 use_mesh_modifiers=True, add_leaf_bones=False, bake_space_transform=True)
        sha = hashlib.sha256(open(fbx, "rb").read()).hexdigest()
        # Blender Z-up: report size as Roblox (x, y=height, z)
        manifest[name] = {"size": [size[0], size[2], size[1]], "sha256": sha, "parts": parts,
                          "tris": sum(p["tris"] for p in parts)}
        print(f"{name}: {len(meshes)} meshes, {manifest[name]['tris']} tris, size(studs) {manifest[name]['size']}")
        if manifest[name]["tris"] > MAX_TRIS:
            sys.exit(f"{name}: {manifest[name]['tris']} triangles is over the {MAX_TRIS} budget (GUIDELINES.md)")
        if do_render:
            render_preview(os.path.join(PREVIEWS, name + ".png"), lo, hi)
            print(f"  preview -> out/art/{name}.png")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
