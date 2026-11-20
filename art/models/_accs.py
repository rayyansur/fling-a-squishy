"""All squishy accessories. Each one is built on its species' body (BODY) inside the shared Pin
frame from _squishy.py, so it lines up with that body. Part names = one colour each."""
import math
from _squishy import *  # noqa: F401,F403

BODY = {
    "acc_steam": "bun", "acc_toasted": "bun", "acc_strawberry": "bun", "acc_leaf": "loaf",
    "acc_raindrop": "blob", "acc_frog_eyes": "bean", "acc_boba": "bun", "acc_avocado": "bean",
    "acc_sushi": "bun", "acc_taco": "loaf", "acc_donut_dragon": "loaf", "acc_cupcake": "loaf",
    "acc_tentacles": "blob", "acc_unicorn": "bun", "acc_crown": "bun", "acc_lava_cracks": "blob",
    "acc_bunny_ears": "bean", "acc_prism": "blob", "acc_gold_steam": "bun", "acc_star_spout": "loaf",
    "acc_party_hat": "blob",
}


def swirl(bpy, kit, name, base, mat, h=0.9, r=0.13, turns=1.3, scale=1.0):
    pts = []
    n = 5
    for k in range(n + 1):
        t = k / n
        a = t * turns * 2 * math.pi
        rr = 0.16 * scale * (1 - t * 0.5)
        pts.append((base[0] + rr * math.cos(a), base[1] + rr * math.sin(a), base[2] + t * h * scale))
    polyline(bpy, name, pts, r * scale * 0.9, mat, sides=5)


def steam(bpy, kit, b, mat, scale=1.0):
    top = top_of(b)
    for x, y, s in ((-0.28, 0.05, 0.8), (0.0, -0.05, 1.0), (0.28, 0.08, 0.75)):
        swirl(bpy, kit, "Steam", (x, y, top - 0.05), mat, h=0.8 * s, r=0.1, scale=scale)


def a_steam(bpy, kit, b):
    steam(bpy, kit, b, M(kit, "#FFFFFF", rough=0.3))
    # pleated top dot of a bao
    ball(bpy, "Pleat", 0.18, (0, 0, top_of(b) - 0.06), M(kit, "#F2E2C4"), scale=(1, 1, 0.5), sides=8, stacks=4)


def a_gold_steam(bpy, kit, b):
    steam(bpy, kit, b, M(kit, "#FFE680", rough=0.2, emit=0.4), scale=1.15)
    ball(bpy, "Pleat", 0.2, (0, 0, top_of(b) - 0.05), M(kit, "#E8A900", rough=0.25, metal=0.6), scale=(1, 1, 0.5), sides=8, stacks=4)


def a_toasted(bpy, kit, b):
    # browned top cap
    body_mesh(bpy, b, M(kit, "#E0A060", rough=0.8), name="Toast", grow=0.025, zmin=1.05)


def a_strawberry(bpy, kit, b):
    top = top_of(b)
    green = M(kit, "#3FBF4A")
    for k in range(6):
        a = 2 * math.pi * k / 6
        tip = (0.5 * math.cos(a), 0.5 * math.sin(a), top - 0.12)
        cone(bpy, "Leaves", 0.14, 0.5, (0.12 * math.cos(a), 0.12 * math.sin(a), top - 0.02), green, sides=4,
             rot=(0, 0, 0), scale=(1, 0.5, 1))
        stick(bpy, "Leaves", (0, 0, top), tip, 0.07, green, sides=4)
    cyl(bpy, "Leaves", 0.05, 0.3, (0, 0, top - 0.02), green, sides=5)
    # seeds
    seed = M(kit, "#FFE680")
    for z, angs in ((0.35, (-50, -15, 20, 55)), (0.75, (-35, 0, 35)), (1.05, (-20, 20))):
        for a in angs:
            if abs(a) < 30 and abs(z - BODIES[b]["eye_z"]) < 0.3:
                continue
            ball(bpy, "Seeds", 0.04, surface(b, a, z, 0.0), seed, scale=(1, 0.6, 1.4), sides=4, stacks=2)
            ball(bpy, "Seeds", 0.04, surface(b, a + 180, z, 0.0), seed, scale=(1, 0.6, 1.4), sides=4, stacks=2)


def a_leaf(bpy, kit, b):
    top = top_of(b)
    stick(bpy, "Stem", (0, 0.05, top - 0.05), (0.05, 0.08, top + 0.25), 0.05, M(kit, "#7A5A44"), sides=5)
    # a flat pointed leaf
    leaf = M(kit, "#4DB52E")
    verts = []
    for t in (0.0, 0.3, 0.6, 0.85, 1.0):
        w = 0.24 * math.sin(math.pi * t) if t < 1 else 0
        verts.append((0.05 + t * 0.7, 0.08 + w, top + 0.22 + t * 0.12))
        verts.append((0.05 + t * 0.7, 0.08 - w, top + 0.22 + t * 0.12))
    faces = []
    for k in range(4):
        a, bb = 2 * k, 2 * k + 2
        faces.append((a, bb, bb + 1, a + 1))
        faces.append((a + 1, bb + 1, bb, a))
    obj_from(bpy, "Leaf", verts, faces, leaf)


def a_raindrop(bpy, kit, b):
    top = top_of(b)
    drop = M(kit, "#7FD3FF", rough=0.2)
    rings(bpy, "Drop", [(0.0, 0.0), (0.18, 0.08), (0.22, 0.2), (0.14, 0.36), (0.0, 0.55)], drop, sides=8,
          center=(0.55, -0.05, top + 0.1))
    rings(bpy, "Drop", [(0.0, 0.0), (0.12, 0.05), (0.15, 0.14), (0.1, 0.25), (0.0, 0.38)], drop, sides=8,
          center=(-0.5, 0.1, top - 0.05))
    # little cloud tuft on top
    w = M(kit, "#FFFFFF")
    for x, z, r in ((-0.15, 0.0, 0.22), (0.12, 0.05, 0.26), (0.0, 0.18, 0.2)):
        ball(bpy, "Tuft", r, (x, 0.05, top - 0.05 + z), w, sides=8, stacks=4)


def a_frog_eyes(bpy, kit, b):
    top = top_of(b)
    g = M(kit, "#7CF25A")
    w, ink = C(kit, "white"), C(kit, "ink")
    for s in (-1, 1):
        c = (s * 0.36, -0.05, top - 0.02)
        ball(bpy, "Bumps", 0.26, c, g, sides=10, stacks=5)
        ball(bpy, "EyeWhite", 0.17, (c[0], c[1] - 0.12, c[2] + 0.04), w, sides=8, stacks=4)
        ball(bpy, "Pupil", 0.08, (c[0], c[1] - 0.27, c[2] + 0.04), ink, sides=6, stacks=3)


def a_boba(bpy, kit, b):
    top = top_of(b)
    ink = M(kit, "#3A2418", rough=0.25)
    # pearls around the lower half
    for z, n, off in ((0.22, 10, 0), (0.48, 9, 0.5)):
        for k in range(n):
            a = 360 * (k + off) / n
            if abs(((a + 180) % 360) - 180) < 40 and z > 0.4:
                continue
            ball(bpy, "Pearls", 0.1, surface(b, a, z, 0.02), ink, sides=6, stacks=3)
    # bear ears + straw
    tan = M(kit, "#C99A6B")
    for s in (-1, 1):
        p = surface(b, s * 50, top - 0.32, -0.05)
        ball(bpy, "Ears", 0.2, (p[0], p[1] * 0.4 + 0.1, p[2] + 0.08), tan, scale=(1, 0.6, 1), sides=8, stacks=4)
    stick(bpy, "Straw", (0.15, 0.1, top - 0.1), (0.35, 0.2, top + 0.75), 0.07, M(kit, "#FF4FA3"), sides=6)


def a_avocado(bpy, kit, b):
    # dark skin shell pushed back: shows on the back and sides, hidden at the front (flesh = body)
    shell = body_mesh(bpy, b, M(kit, "#3E7B27", rough=0.7), name="Skin", grow=0.04, zmin=0.06)
    for v in shell.data.vertices:
        v.co.y += 0.14
    pz = 0.55
    ball(bpy, "Pit", 0.24, (0, front_y(b, 0, pz) - 0.08, pz), M(kit, "#8B5A2B", rough=0.4), scale=(1, 0.6, 1.1), sides=10, stacks=5)


def a_sushi(bpy, kit, b):
    # nori band + salmon top
    body_mesh(bpy, b, M(kit, "#1F3A2E", rough=0.8), name="Nori", grow=0.03, zmin=0.08, zmax=0.42)
    top = top_of(b)
    salmon = M(kit, "#FF8A65")
    rings(bpy, "Salmon", [(0.0, 0.0), (0.82, 0.0), (0.86, 0.1), (0.7, 0.2), (0.0, 0.24)], salmon, sx=1.0, sy=0.62,
          sides=12, center=(0, 0.08, top - 0.18), rot=(-8, 0, 0))
    w = M(kit, "#FFD0BC")
    for k in range(3):
        x = -0.4 + 0.4 * k
        stick(bpy, "Stripes", (x - 0.12, -0.25, top + 0.05), (x + 0.12, 0.35, top + 0.05), 0.035, w, sides=4)


def a_taco(bpy, kit, b):
    top = top_of(b)
    shell = M(kit, "#F5B83A", rough=0.75)
    # one U-shaped shell: an arc under and up both sides, running front to back
    cz, R, t = 1.25, 1.13, 0.1
    n = 12
    arc = [math.radians(-95 + 190 * k / n) for k in range(n + 1)]  # 0 = straight down
    verts, faces = [], []
    for y in (-0.72, 0.72):
        for a in arc:
            for rr in (R, R + t):
                verts.append((rr * math.sin(a), y, cz - rr * math.cos(a)))
    per = 2 * (n + 1)
    for k in range(n):
        i = 2 * k
        faces.append((i + 1, i + 3, per + i + 3, per + i + 1))  # outer
        faces.append((i, per + i, per + i + 2, i + 2))  # inner
        faces.append((i, i + 2, i + 3, i + 1))  # front rim
        faces.append((per + i, per + i + 1, per + i + 3, per + i + 2))  # back rim
    for e in (0, 2 * n):
        faces.append((e, e + 1, per + e + 1, per + e))
    obj_from(bpy, "Shell", verts, faces, shell)
    lett = M(kit, "#6BD34A")
    tom = M(kit, "#FF4F4F")
    for k in range(5):
        y = -0.6 + 0.3 * k
        for s in (-1, 1):
            ball(bpy, "Lettuce", 0.16, (s * 0.98, y, top + 0.02), lett, scale=(0.8, 1.2, 0.7), sides=6, stacks=3)
    for x, y in ((-0.45, -0.1), (0.4, 0.2), (0.0, 0.45)):
        cyl(bpy, "Tomato", 0.15, 0.08, (x, y, top - 0.04), tom, sides=8)


def a_donut_dragon(bpy, kit, b):
    top = top_of(b)
    # donut ring around the middle, sprinkles, little wings + horns
    torus = M(kit, "#C98A4B", rough=0.7)
    icing = M(kit, "#FFB3D9", rough=0.4)
    zc = 0.5
    R, r = 1.0, 0.2
    for mat, name, dz, cut in ((torus, "Donut", 0, False), (icing, "Icing", 0.07, True)):
        verts, faces = [], []
        U, V = 16, 6
        for i in range(U):
            u = 2 * math.pi * i / U
            for j in range(V):
                v = 2 * math.pi * j / V
                rr = r + (0.02 if cut else 0)
                x = (R + rr * math.cos(v)) * math.cos(u)
                y = (R + rr * math.cos(v)) * math.sin(u) * BODIES[b]["sy"]
                z = zc + dz + rr * math.sin(v) * (0.7 if cut else 1)
                verts.append((x, y, z))
        for i in range(U):
            for j in range(V):
                if cut and not (0 <= j < 3):
                    continue
                a = i * V + j
                bb = ((i + 1) % U) * V + j
                c = ((i + 1) % U) * V + (j + 1) % V
                d = i * V + (j + 1) % V
                faces.append((a, bb, c, d))
        obj_from(bpy, name, verts, faces, mat)
    for k in range(10):
        u = 2 * math.pi * k / 10 + 0.3
        x, y = (R + 0.05) * math.cos(u), (R + 0.05) * math.sin(u) * BODIES[b]["sy"]
        stick(bpy, "Sprinkles", (x - 0.06, y, zc + 0.24), (x + 0.06, y + 0.04, zc + 0.24), 0.03,
              M(kit, ["#3EC5FF", "#FFD23F", "#7CF25A"][k % 3]), sides=4)
    wing = M(kit, "#9B5CFF")
    for s in (-1, 1):
        verts = [(s * 0.6, 0.55, 1.0), (s * 1.3, 0.75, 1.55), (s * 1.15, 0.7, 1.05), (s * 1.45, 0.8, 1.15), (s * 0.85, 0.65, 0.75)]
        obj_from(bpy, "Wings", verts, [(0, 1, 2), (2, 1, 3), (0, 2, 4), (0, 2, 1), (2, 3, 1), (0, 4, 2)], wing)
        cone(bpy, "Horns", 0.09, 0.32, (s * 0.25, 0.1, top - 0.05), M(kit, "#FFD23F"), sides=5, rot=(0, s * -15, 0))


def a_cupcake(bpy, kit, b):
    top = top_of(b)
    # paper wrapper on the bottom, frosting swirl and a cherry on top
    wrap = M(kit, "#7FD3FF")
    verts, faces = [], []
    n = 16
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = 1.06 if k % 2 == 0 else 1.12
        for z, sc in ((0.0, 0.94), (0.5, 1.0)):
            verts.append((rr * sc * math.cos(a), rr * sc * math.sin(a) * BODIES[b]["sy"], z))
    for k in range(n):
        k1 = (k + 1) % n
        faces.append((2 * k, 2 * k1, 2 * k1 + 1, 2 * k + 1))
    obj_from(bpy, "Wrapper", verts, faces, wrap)
    fro = M(kit, "#FFFFFF", rough=0.4)
    for k, (rr, z) in enumerate(((0.62, 0.0), (0.45, 0.2), (0.25, 0.38))):
        ball(bpy, "Frosting", rr, (0, 0.05, top - 0.05 + z), fro, scale=(1, 1, 0.5), sides=12, stacks=4)
    ball(bpy, "Cherry", 0.15, (0, 0.05, top + 0.55), M(kit, "#E8243C", rough=0.25), sides=8, stacks=4)
    stick(bpy, "Stem", (0, 0.05, top + 0.66), (0.08, 0.1, top + 0.86), 0.025, M(kit, "#4DB52E"), sides=4)


def a_tentacles(bpy, kit, b):
    pm = M(kit, "#9B6BFF")
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        pts = []
        for t in range(5):
            r = 0.78 + 0.13 * t
            z = 0.18 + 0.05 * math.sin(t * 1.6)
            ang = a + 0.25 * math.sin(t * 1.2)
            pts.append((r * math.cos(ang), r * math.sin(ang), z))
        for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
            stick(bpy, "Tentacles", p0, p1, 0.16 - 0.03 * i, pm, sides=5)
        for p in pts[1:-1]:
            ball(bpy, "Tentacles", 0.12, p, pm, sides=5, stacks=3)
    spot = M(kit, "#E3D1FF")
    for a, z in ((60, 1.0), (-70, 0.9), (150, 0.7), (200, 1.1)):
        ball(bpy, "Spots", 0.13, surface(b, a, z, -0.03), spot, scale=(1, 1, 0.7), sides=6, stacks=3)


def a_unicorn(bpy, kit, b):
    top = top_of(b)
    gold = M(kit, "#FFD23F", rough=0.3, metal=0.3)
    cone(bpy, "Horn", 0.16, 0.75, (0, -0.25, top - 0.12), gold, sides=6, rot=(-15, 0, 0))
    mane_cols = ["#FF4FA3", "#9B5CFF", "#3EC5FF", "#7CF25A"]
    for k, c in enumerate(mane_cols):
        z = top - 0.08 - k * 0.18
        y = 0.25 + k * 0.17
        ball(bpy, "Mane" + str(k + 1), 0.24, (0, y, z), M(kit, c), scale=(0.8, 1.1, 0.9), sides=8, stacks=4)
    for s in (-1, 1):
        p = surface(b, s * 55, top - 0.3, -0.05)
        cone(bpy, "Ears", 0.13, 0.32, p, M(kit, "#FFFFFF"), sides=5, rot=(0, s * -25, 0))


def a_crown(bpy, kit, b):
    top = top_of(b)
    gold = M(kit, "#FFD23F", rough=0.25, metal=0.6)
    base_z = top - 0.22
    n = 10
    verts, faces = [], []
    rr = 0.48
    for k in range(n):
        a = 2 * math.pi * k / n
        h = 0.62 if k % 2 == 0 else 0.3
        verts += [(rr * math.cos(a), rr * math.sin(a), base_z), (rr * math.cos(a), rr * math.sin(a), base_z + h)]
    for k in range(n):
        k1 = (k + 1) % n
        faces.append((2 * k, 2 * k1, 2 * k1 + 1, 2 * k + 1))
        faces.append((2 * k + 1, 2 * k1 + 1, 2 * k1, 2 * k))
    obj_from(bpy, "Crown", verts, faces, gold)
    for k in range(0, n, 2):
        a = 2 * math.pi * k / n
        ball(bpy, "Gems", 0.07, (rr * math.cos(a), rr * math.sin(a), base_z + 0.68), M(kit, "#FF4FA3", rough=0.15), sides=6, stacks=3)
    # cake layers: frosting drips band + candle-like cherry
    body_mesh(bpy, b, M(kit, "#FF9EC7", rough=0.45), name="Frosting", grow=0.025, zmin=0.95)
    for a in range(-150, 180, 30):
        ball(bpy, "Frosting", 0.09, surface(b, a, 0.95, 0.0), M(kit, "#FF9EC7", rough=0.45), scale=(1, 1, 1.6), sides=6, stacks=3)


def a_lava_cracks(bpy, kit, b):
    glow = M(kit, "#FFD23F", emit=2.0)
    for a0 in (30, 110, 200, 290):
        pts = []
        for k in range(5):
            z = 0.15 + 0.3 * k
            a = a0 + 18 * math.sin(k * 1.9)
            if abs(((a + 180) % 360) - 180) < 35 and 0.4 < z < 0.95:
                continue
            pts.append(surface(b, a, min(z, 1.55), 0.01))
        if len(pts) > 1:
            polyline(bpy, "Cracks", pts, 0.05, glow, sides=4)


def a_bunny_ears(bpy, kit, b):
    top = top_of(b)
    ice = M(kit, "#BFF3FF", rough=0.15)
    pink = M(kit, "#FFB3D9", rough=0.3)
    for s in (-1, 1):
        base = (s * 0.3, 0.05, top - 0.15)
        rot = (0, s * -12, 0)
        rings(bpy, "Ears", [(0.0, 0.0), (0.15, 0.05), (0.2, 0.5), (0.16, 1.05), (0.0, 1.2)], ice, sx=1.0, sy=0.5, sides=8, center=base, rot=rot)
        rings(bpy, "Inner", [(0.0, 0.1), (0.09, 0.15), (0.12, 0.5), (0.08, 0.98), (0.0, 1.08)], pink, sx=1.0, sy=0.3, sides=8,
              center=(base[0], base[1] - 0.06, base[2]), rot=rot)
    # crystal facets on the back
    for a, z in ((150, 1.4), (200, 1.0), (175, 0.6)):
        p = surface(b, a, z, -0.05)
        cone(bpy, "Crystals", 0.14, 0.38, p, M(kit, "#E8FBFF", rough=0.05), sides=4, rot=(-60, 0, 0))


def a_prism(bpy, kit, b):
    top = top_of(b)
    # floating crystal shards in a ring + a gem on top
    for k in range(5):
        a = 2 * math.pi * k / 5
        c = ["#FF4FA3", "#FFD23F", "#7CF25A", "#3EC5FF", "#9B5CFF"][k]
        rings(bpy, "Shard" + str(k + 1), [(0.0, 0.0), (0.13, 0.18), (0.0, 0.5)], M(kit, c, rough=0.1, emit=0.3), sides=4,
              center=(1.25 * math.cos(a), 1.25 * math.sin(a), 0.9 + 0.2 * math.sin(a * 2)))
    rings(bpy, "Gem", [(0.0, 0.0), (0.24, 0.24), (0.18, 0.4), (0.0, 0.48)], M(kit, "#FFFFFF", rough=0.05, emit=0.5), sides=6,
          center=(0, 0, top - 0.06))


def a_star_spout(bpy, kit, b):
    top = top_of(b)
    spout = M(kit, "#8FE0FF", emit=0.5)
    pts = [(0, 0.15, top - 0.05), (0, 0.13, top + 0.35), (0, 0.1, top + 0.65)]
    polyline(bpy, "Spout", pts, 0.09, spout, sides=6)
    for s in (-1, 1):
        stick(bpy, "Spout", pts[-1], (s * 0.32, 0.1, top + 0.82), 0.07, spout, sides=6)
    star(bpy, "Star", 0.28, (0, 0.1, top + 1.0), M(kit, "#FFD23F", emit=1.2), thick=0.1)
    # tail fluke at the back + belly
    tail = M(kit, "#3A2E8C")
    for s in (-1, 1):
        cone(bpy, "Body", 0.22, 0.5, (s * 0.1, 0.95, 0.55), tail, sides=5, rot=(-70, s * 35, 0))
    body_mesh(bpy, b, M(kit, "#B8A8FF"), name="Belly", grow=0.02, zmin=0.0, zmax=0.28)
    for a, z in ((40, 1.0), (-60, 1.1), (140, 0.8), (210, 1.0), (100, 0.5)):
        star(bpy, "Specks", 0.07, surface(b, a, z, 0.0), M(kit, "#FFFFFF", emit=1.0), thick=0.03, rot=(90, 0, a))


def a_party_hat(bpy, kit, b):
    top = top_of(b)
    hat = M(kit, "#3EC5FF")
    cone(bpy, "Hat", 0.42, 1.0, (0.1, 0.0, top - 0.12), hat, sides=10, rot=(0, 10, 0))
    stripe = M(kit, "#FFD23F")
    for k, (h, r) in enumerate(((0.25, 0.33), (0.55, 0.2))):
        rings(bpy, "Stripes", [(0.0, 0.0), (r + 0.02, 0.0), (r - 0.03, 0.1), (0.0, 0.1)], stripe, sides=10,
              center=(0.1 + h * math.sin(math.radians(10)), 0, top - 0.12 + h * math.cos(math.radians(10))))
    ball(bpy, "Pompom", 0.16, (0.1 + math.sin(math.radians(10)) * 1.0, 0, top - 0.12 + 1.0), M(kit, "#FF4FA3"), sides=8, stacks=4)
    # confetti specks
    for k in range(10):
        a = k * 37
        z = 0.3 + (k % 4) * 0.35
        if abs(((a + 180) % 360) - 180) < 40 and 0.35 < z < 0.95:
            continue
        ball(bpy, "Confetti", 0.06, surface(b, a, z, 0.0), M(kit, ["#FF4FA3", "#FFD23F", "#7CF25A", "#9B5CFF"][k % 4]), sides=4, stacks=2)


BUILDERS = {
    "acc_steam": a_steam, "acc_toasted": a_toasted, "acc_strawberry": a_strawberry, "acc_leaf": a_leaf,
    "acc_raindrop": a_raindrop, "acc_frog_eyes": a_frog_eyes, "acc_boba": a_boba, "acc_avocado": a_avocado,
    "acc_sushi": a_sushi, "acc_taco": a_taco, "acc_donut_dragon": a_donut_dragon, "acc_cupcake": a_cupcake,
    "acc_tentacles": a_tentacles, "acc_unicorn": a_unicorn, "acc_crown": a_crown, "acc_lava_cracks": a_lava_cracks,
    "acc_bunny_ears": a_bunny_ears, "acc_prism": a_prism, "acc_gold_steam": a_gold_steam, "acc_star_spout": a_star_spout,
    "acc_party_hat": a_party_hat,
}


def build_acc(bpy, kit, name):
    BUILDERS[name](bpy, kit, BODY[name])
    pins(bpy, kit)
