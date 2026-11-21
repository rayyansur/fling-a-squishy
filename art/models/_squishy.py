"""Shared low-poly helpers for Throw a Squishy (DESIGN 9.1: flat-shaded low-poly, chunky rounded
silhouettes, solid candy colours). Blender Z is up; a model's front faces Blender -Y.

Squishy frame (scale 1 = about 2 studs wide): every body and every accessory carries two tiny
"Pin" markers at the same far corners, so they share one bounding box, one pivot after upload,
and accessories line up with their body without offsets. The client deletes the Pin parts.
"""
import math

PAL = {
    "pink": "#FF4FA3", "sky": "#3EC5FF", "lime": "#7CF25A", "lemon": "#FFD23F", "grape": "#9B5CFF",
    "orange": "#FF8A3D", "taffy": "#FFB3D9", "cream": "#FFE3F1", "ink": "#2B1B4A", "white": "#FFFFFF",
    "blush": "#FF9EC7", "berry": "#C2286F", "mint": "#B8F5D0",
}

PIN_LO = (-1.5, -1.5, 0.0)
PIN_HI = (1.5, 1.5, 3.6)
SIDES = 14


def M(kit, hexc, rough=0.55, metal=0.0, emit=0.0):
    return kit.mat(f"m{hexc}{rough}{metal}{emit}", hexc, rough, metal, emit)


def C(kit, key, **kw):
    return M(kit, PAL[key], **kw)


def obj_from(bpy, name, verts, faces, mat, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    if mat is not None:
        o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def xf(v, center=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    x, y, z = v[0] * scale[0], v[1] * scale[1], v[2] * scale[2]
    rx, ry, rz = (math.radians(a) for a in rot)
    y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
    x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
    x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
    return (x + center[0], y + center[1], z + center[2])


def rings(bpy, name, profile, mat, sx=1.0, sy=1.0, n=2.0, sides=SIDES, center=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), smooth=False):
    """Stack of superellipse rings: profile = [(radius, z)], first/last radius 0 make caps.
    n = 2 is a circle; n = 4 is a rounded square (loaf). sx/sy stretch the cross-section."""
    verts, faces = [], []
    ring_idx = []
    for r, z in profile:
        if r <= 1e-6:
            ring_idx.append([len(verts)])
            verts.append((0, 0, z))
            continue
        idx = []
        for j in range(sides):
            a = 2 * math.pi * j / sides + math.pi / sides
            c, s = math.cos(a), math.sin(a)
            px = r * sx * math.copysign(abs(c) ** (2 / n), c)
            py = r * sy * math.copysign(abs(s) ** (2 / n), s)
            idx.append(len(verts))
            verts.append((px, py, z))
        ring_idx.append(idx)
    for k in range(len(ring_idx) - 1):
        a, b = ring_idx[k], ring_idx[k + 1]
        if len(a) == 1 and len(b) > 1:
            for j in range(sides):
                faces.append((a[0], b[(j + 1) % sides], b[j]))
        elif len(a) > 1 and len(b) == 1:
            for j in range(sides):
                faces.append((a[j], a[(j + 1) % sides], b[0]))
        elif len(a) > 1 and len(b) > 1:
            for j in range(sides):
                j1 = (j + 1) % sides
                faces.append((a[j], a[j1], b[j1], b[j]))
    verts = [xf(v, center, scale, rot) for v in verts]
    return obj_from(bpy, name, verts, faces, mat, smooth)


def ball(bpy, name, r, center, mat, scale=(1, 1, 1), rot=(0, 0, 0), sides=8, stacks=5):
    prof = []
    for i in range(stacks + 1):
        ph = -math.pi / 2 + math.pi * i / stacks
        prof.append((r * math.cos(ph) if 0 < i < stacks else 0.0, r * math.sin(ph)))
    return rings(bpy, name, prof, mat, sides=sides, center=center, scale=scale, rot=rot)


def cone(bpy, name, r, h, base, mat, sides=8, rot=(0, 0, 0), scale=(1, 1, 1), r_top=0.0):
    prof = [(0.0, 0.0), (r, 0.0), (r_top, h)] if r_top <= 0 else [(0.0, 0.0), (r, 0.0), (r_top, h), (0.0, h)]
    return rings(bpy, name, prof, mat, sides=sides, center=base, rot=rot, scale=scale)


def cyl(bpy, name, r, h, base, mat, sides=10, rot=(0, 0, 0), scale=(1, 1, 1)):
    return rings(bpy, name, [(0.0, 0.0), (r, 0.0), (r, h), (0.0, h)], mat, sides=sides, center=base, rot=rot, scale=scale)


def stick(bpy, name, a, b, r, mat, sides=6):
    """A straight round rod from a to b."""
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    verts, faces = [], []
    # orthonormal frame around the rod
    ax = (dx / length, dy / length, dz / length)
    up = (0, 0, 1) if abs(ax[2]) < 0.9 else (1, 0, 0)
    u = (ax[1] * up[2] - ax[2] * up[1], ax[2] * up[0] - ax[0] * up[2], ax[0] * up[1] - ax[1] * up[0])
    ul = math.sqrt(sum(c * c for c in u))
    u = tuple(c / ul for c in u)
    v = (ax[1] * u[2] - ax[2] * u[1], ax[2] * u[0] - ax[0] * u[2], ax[0] * u[1] - ax[1] * u[0])
    for end in (a, b):
        for j in range(sides):
            t = 2 * math.pi * j / sides
            verts.append(tuple(end[i] + r * (math.cos(t) * u[i] + math.sin(t) * v[i]) for i in range(3)))
    for j in range(sides):
        j1 = (j + 1) % sides
        faces.append((j, j1, sides + j1, sides + j))
    faces.append(tuple(range(sides - 1, -1, -1)))
    faces.append(tuple(range(sides, 2 * sides)))
    return obj_from(bpy, name, verts, faces, mat)


def polyline(bpy, name, pts, r, mat, sides=5):
    for a, b in zip(pts, pts[1:]):
        stick(bpy, name, a, b, r, mat, sides)
    for p in pts[1:-1]:
        ball(bpy, name, r, p, mat, sides=sides, stacks=3)


def star(bpy, name, r, center, mat, thick=0.12, rot=(90, 0, 0), points=5):
    """A chunky 5-point star, flat in its local XY plane."""
    verts, faces = [], []
    outer = []
    for k in range(points * 2):
        a = math.pi / 2 + math.pi * k / points
        rr = r if k % 2 == 0 else r * 0.45
        outer.append((rr * math.cos(a), rr * math.sin(a)))
    n = len(outer)
    for z in (-thick / 2, thick / 2):
        verts.append((0, 0, z))
        for x, y in outer:
            verts.append((x, y, z))
    for k in range(n):
        k1 = (k + 1) % n
        faces.append((0, 1 + k1, 1 + k))
        faces.append((n + 1, n + 2 + k, n + 2 + k1))
        faces.append((1 + k, 1 + k1, n + 2 + k1, n + 2 + k))
    verts = [xf(v, center, (1, 1, 1), rot) for v in verts]
    return obj_from(bpy, name, verts, faces, mat)


def pins(bpy, kit):
    """The two shared bounding markers (deleted at runtime)."""
    m = M(kit, "#FF00FF")
    ball(bpy, "Pin", 0.02, (PIN_LO[0] + 0.02, PIN_LO[1] + 0.02, PIN_LO[2] + 0.02), m, sides=3, stacks=2)
    ball(bpy, "Pin", 0.02, (PIN_HI[0] - 0.02, PIN_HI[1] - 0.02, PIN_HI[2] - 0.02), m, sides=3, stacks=2)


# ------------------------------------------------------------------ bodies
# profile (radius, z), cross-section stretch (sx, sy), superellipse n, eye height
BODIES = {
    "bun": {"profile": [(0.0, 0.0), (0.82, 0.0), (0.97, 0.1), (1.0, 0.32), (0.94, 0.72), (0.78, 1.06), (0.5, 1.33), (0.0, 1.45)],
            "sx": 1.0, "sy": 0.95, "n": 2.0, "eye_z": 0.68, "top": 1.45},
    "bean": {"profile": [(0.0, 0.0), (0.5, 0.0), (0.7, 0.16), (0.78, 0.55), (0.78, 1.45), (0.7, 1.86), (0.48, 2.12), (0.0, 2.24)],
             "sx": 1.0, "sy": 0.92, "n": 2.0, "eye_z": 1.32, "top": 2.24},
    "blob": {"profile": [(0.0, 0.0), (0.92, 0.0), (1.06, 0.14), (1.04, 0.42), (0.86, 0.82), (0.58, 1.2), (0.32, 1.52), (0.12, 1.74), (0.0, 1.8)],
             "sx": 1.0, "sy": 0.95, "n": 2.0, "eye_z": 0.62, "top": 1.8},
    "loaf": {"profile": [(0.0, 0.0), (0.88, 0.0), (0.99, 0.12), (1.0, 0.4), (0.97, 0.85), (0.86, 1.12), (0.62, 1.3), (0.0, 1.36)],
             "sx": 1.0, "sy": 0.82, "n": 3.2, "eye_z": 0.72, "top": 1.36},
}


def radius_at(body, z):
    """Body radius (before sx/sy) at height z, linear between profile rings."""
    prof = BODIES[body]["profile"]
    for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
        if z0 <= z <= z1 and z1 > z0:
            t = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    return 0.0


def front_y(body, x, z):
    """Front surface y (negative, Blender front) of a body at (x, z)."""
    b = BODIES[body]
    r = radius_at(body, z)
    a, bb, n = r * b["sx"], r * b["sy"], b["n"]
    if a <= 1e-6 or abs(x) >= a:
        return 0.0
    return -bb * (1 - abs(x / a) ** n) ** (1 / n)


def surface(body, angle_deg, z, out=0.0):
    """Point on the body surface: angle 0 = front (-Y), 90 = +X."""
    b = BODIES[body]
    r = radius_at(body, z) + out
    t = math.radians(angle_deg)
    c, s = math.sin(t), -math.cos(t)
    n = b["n"]
    px = r * b["sx"] * math.copysign(abs(c) ** (2 / n), c)
    py = r * b["sy"] * math.copysign(abs(s) ** (2 / n), s)
    return (px, py, z)


def body_mesh(bpy, body, mat, name="Body", grow=0.0, zmin=None, zmax=None):
    """The body, or a shell slice of it (grow > 0, zmin..zmax) for caps, bands and frosting."""
    b = BODIES[body]
    prof = [(r + (grow if r > 0 else 0), z) for r, z in b["profile"]]
    if zmin is not None or zmax is not None:
        lo = zmin if zmin is not None else 0.0
        hi = zmax if zmax is not None else b["top"]
        sl = [(radius_at(body, lo) + grow, lo)]
        sl += [(r, z) for r, z in prof if lo < z < hi]
        top_r = radius_at(body, hi) + grow if hi < b["top"] else 0.0
        sl.append((top_r, hi if hi < b["top"] else b["top"] + grow))
        # close the slice: inner caps at both ends
        prof = [(0.0, lo)] + sl + ([(0.0, hi)] if top_r > 0 else [])
    return rings(bpy, name, prof, mat, sx=b["sx"], sy=b["sy"], n=b["n"])


def face(bpy, kit, body):
    """The shared face: oval eyes with a white shine, blush ovals, a tiny 'w' mouth."""
    b = BODIES[body]
    ink, white, blush = C(kit, "ink"), C(kit, "white"), C(kit, "blush")
    ez = b["eye_z"]
    for s in (-1, 1):
        ex = s * 0.3
        fy = front_y(body, ex, ez)
        ball(bpy, "Eyes", 0.1, (ex, fy + 0.02, ez), ink, scale=(0.9, 0.55, 1.35), sides=8, stacks=5)
        ball(bpy, "Shine", 0.035, (ex - 0.03, fy - 0.035, ez + 0.06), white, sides=6, stacks=3)
        bx = s * 0.56
        by = front_y(body, bx, ez - 0.14)
        ball(bpy, "Blush", 0.1, (bx, by + 0.03, ez - 0.14), blush, scale=(1.25, 0.35, 0.7), sides=8, stacks=4)
    mz = ez - 0.17
    pts = []
    for k, (x, dz) in enumerate([(-0.12, 0.0), (-0.06, -0.055), (0.0, 0.0), (0.06, -0.055), (0.12, 0.0)]):
        pts.append((x, front_y(body, x, mz + dz) - 0.005, mz + dz))
    polyline(bpy, "Mouth", pts, 0.022, ink, sides=4)


def ears(bpy, body, mat, name="Body"):
    """Cat-loaf ear nubs (part of the loaf body, same colour)."""
    top = BODIES[body]["top"]
    for s in (-1, 1):
        cone(bpy, name, 0.3, 0.46, (s * 0.55, 0.05, top - 0.14), mat, sides=6, rot=(0, s * -12, 0))


def body_model(bpy, kit, body):
    m = M(kit, "#FFFFFF")
    body_mesh(bpy, body, m)
    if body == "loaf":
        ears(bpy, body, m)
    face(bpy, kit, body)
    pins(bpy, kit)


def top_of(body):
    return BODIES[body]["top"]
