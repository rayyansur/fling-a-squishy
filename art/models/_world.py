"""World models for Fling a Squishy: candy low-poly, chunky, flat-shaded, saturated (DESIGN 9).
Front faces Blender -Y (Roblox -Z); the map rotates models to face where they need to."""
import math
import random
from _squishy import *  # noqa: F401,F403


def box(bpy, kit, name, sx, sy, sz, x, y, z, mat, bevel=0.0):
    o = kit.box(name, sx, sy, sz, x, y, z, mat, bevel)
    return o


def curved_slab(bpy, name, x0, x1, y_front, depth, z0, z1, curve, half, mat, segs=12):
    """A slab spanning x0..x1 whose front edge bows forward (-Y) by curve*(x/half)^2."""
    verts, faces = [], []
    for k in range(segs + 1):
        x = x0 + (x1 - x0) * k / segs
        off = -curve * (x / half) ** 2
        for y in (y_front + off, y_front + off + depth):
            for z in (z0, z1):
                verts.append((x, y, z))
    for k in range(segs):
        i, j = 4 * k, 4 * (k + 1)
        faces.append((i + 1, j + 1, j + 3, i + 3))  # top
        faces.append((i, i + 2, j + 2, j))  # bottom
        faces.append((i, j, j + 1, i + 1))  # front
        faces.append((i + 2, i + 3, j + 3, j + 2))  # back
    faces.append((0, 1, 3, 2))
    e = 4 * segs
    faces.append((e, e + 2, e + 3, e + 1))
    return obj_from(bpy, name, verts, faces, mat)


# ------------------------------------------------------------------ goo blob
def goo_blob(bpy, kit):
    # round front (-Y, direction of travel) with a short tail; part "Body" is recoloured per goo
    rings(bpy, "Body", [(0.0, -1.0), (0.55, -0.95), (0.9, -0.6), (1.0, -0.1), (0.85, 0.35), (0.5, 0.85), (0.2, 1.25), (0.0, 1.45)],
          M(kit, "#FF4FA3", rough=0.25), sides=12, center=(0, 0, 1.0), rot=(-90, 0, 0))
    ball(bpy, "Shine", 0.22, (-0.35, -0.75, 1.5), M(kit, "#FFFFFF", rough=0.1), scale=(1, 0.6, 0.8), sides=8, stacks=4)


# ------------------------------------------------------------------ slingshot
def slingshot(bpy, kit):
    wood = M(kit, "#FF4FA3", rough=0.45)
    stripe = M(kit, "#FFFFFF", rough=0.45)
    gum = M(kit, "#9B5CFF", rough=0.5)
    # gumdrop base
    rings(bpy, "Base", [(0.0, 0.0), (1.8, 0.0), (1.75, 0.35), (1.3, 0.9), (0.6, 1.2), (0.0, 1.25)], gum, sides=10)
    # trunk and the two arms (candy-cane striped)
    trunk = [(0, 0, 0.8), (0, 0, 4.4)]
    stick(bpy, "Frame", trunk[0], trunk[1], 0.42, wood, sides=8)
    ball(bpy, "Frame", 0.5, (0, 0, 4.4), wood, sides=8, stacks=4)
    for s in (-1, 1):
        mid = (s * 1.6, 0, 5.6)
        tip = (s * 2.2, 0, 7.4)
        stick(bpy, "Frame", (0, 0, 4.4), mid, 0.36, wood, sides=8)
        stick(bpy, "Frame", mid, tip, 0.32, wood, sides=8)
        ball(bpy, "Frame", 0.36, mid, wood, sides=8, stacks=4)
        ball(bpy, "Tips", 0.42, (tip[0], tip[1], tip[2] + 0.1), M(kit, "#FFD23F", rough=0.4), sides=8, stacks=4)
    # spiral stripes on the trunk
    for k in range(5):
        z = 1.2 + 0.7 * k
        rings(bpy, "Stripes", [(0.0, 0.0), (0.45, 0.0), (0.45, 0.22), (0.0, 0.22)], stripe, sides=8,
              center=(0, 0, z), rot=(0, 18, 0))
    # bow
    bow = M(kit, "#3EC5FF", rough=0.4)
    for s in (-1, 1):
        cone(bpy, "Bow", 0.38, 0.6, (0, -0.42, 3.0), bow, sides=4, rot=(0, s * 90, 0), scale=(1, 0.5, 1))
    ball(bpy, "Bow", 0.16, (0, -0.45, 3.0), bow, sides=6, stacks=3)


# ------------------------------------------------------------------ shelf L1
SHELF = {"tier_z": (1.0, 3.4, 5.8), "tier_y": (2.6, 1.2, -0.2), "half": 11.0, "curve": 0.9, "depth": 2.4}


def shelf(bpy, kit, level=1):
    board = M(kit, "#FFB3D9", rough=0.45)
    lip = M(kit, "#FF4FA3", rough=0.45)
    drip = M(kit, "#FFFFFF", rough=0.35)
    post = M(kit, "#9B5CFF", rough=0.45)
    half = SHELF["half"]
    for k, (tz, ty) in enumerate(zip(SHELF["tier_z"], SHELF["tier_y"])):
        yf = -ty - SHELF["depth"] / 2
        curved_slab(bpy, "Boards", -half - 0.4, half + 0.4, yf, SHELF["depth"], tz - 0.4, tz, SHELF["curve"], half, board)
        # rounded lip along the front edge
        curved_slab(bpy, "Lips", -half - 0.4, half + 0.4, yf - 0.25, 0.35, tz - 0.55, tz + 0.03, SHELF["curve"], half, lip)
        # frosting drips under the lip
        for i in range(12):
            x = -half + (2 * half) * (i + 0.5) / 12
            y = yf - 0.12 - SHELF["curve"] * (x / half) ** 2
            ball(bpy, "Drips", 0.22, (x, y, tz - 0.6), drip, scale=(1, 0.6, 1.5), sides=6, stacks=3)
        # riser: the step front below each tier down to the one below
        below = SHELF["tier_z"][k - 1] if k > 0 else 0.0
        if tz - 0.55 > below:
            curved_slab(bpy, "Boards", -half - 0.4, half + 0.4, yf + 0.1, SHELF["depth"] - 0.2 + (1.4 if k < 2 else 0.4),
                        below, tz - 0.4, SHELF["curve"], half, board)
    # back wall with a scalloped top
    back_y = -SHELF["tier_y"][-1] + SHELF["depth"] / 2
    box(bpy, kit, "Back", 2 * half + 0.8, 0.5, 8.0, 0, back_y + 0.25, 0, board)
    for i in range(9):
        x = -half + 2 * half * (i + 0.5) / 9
        ball(bpy, "Scallops", 1.25, (x, back_y + 0.25, 8.0), lip, scale=(1, 0.35, 0.8), sides=10, stacks=4)
    # lollipop posts on both ends
    for s in (-1, 1):
        x = s * (half + 0.9)
        cyl(bpy, "Posts", 0.35, 8.6, (x, -1.0, 0), post, sides=8)
        ball(bpy, "PostTops", 1.0, (x, -1.0, 9.4), M(kit, "#FFD23F", rough=0.4), scale=(1, 0.45, 1), sides=12, stacks=5)
        star(bpy, "PostStars", 0.45, (x, -1.48, 9.4), M(kit, "#FFFFFF"), thick=0.1)
    pins_box(bpy, kit, (-half - 1.5, -5.0, 0.0), (half + 1.5, 5.0, 10.6))


def pins_box(bpy, kit, lo, hi):
    """Pins that centre a model's bounding box on the origin (map code hides them)."""
    m = M(kit, "#FF00FF")
    ball(bpy, "Pin", 0.02, (lo[0] + 0.02, lo[1] + 0.02, lo[2] + 0.02), m, sides=3, stacks=2)
    ball(bpy, "Pin", 0.02, (hi[0] - 0.02, hi[1] - 0.02, hi[2] - 0.02), m, sides=3, stacks=2)


# ------------------------------------------------------------------ jelly pad
def jelly_pad(bpy, kit):
    # one colour (the map recolours every part to the pad colour)
    rings(bpy, "Jelly", [(0.0, 0.0), (9.0, 0.0), (9.0, 0.45), (8.6, 0.95), (7.4, 1.35), (5.0, 1.6), (0.0, 1.7)],
          M(kit, "#FF4FA3", rough=0.2), sides=20)


# ------------------------------------------------------------------ valley props
def gumdrop_bush(bpy, kit):
    rnd = random.Random(7)
    cols = ["#FF4FA3", "#7CF25A", "#FFD23F", "#3EC5FF", "#9B5CFF", "#FF8A3D"]
    spots = [(0, 0, 1.0), (-2.6, 1.0, 0.75), (2.4, 0.8, 0.8), (-1.0, -2.2, 0.7), (1.6, -1.9, 0.65), (0.4, 2.4, 0.7)]
    for i, (x, y, s) in enumerate(spots):
        c = M(kit, cols[i % len(cols)], rough=0.35)
        r, h = 1.9 * s, 2.6 * s
        rings(bpy, "Drop" + str(i % 6 + 1), [(0.0, 0.0), (r, 0.0), (r * 0.98, h * 0.3), (r * 0.75, h * 0.7), (r * 0.35, h * 0.95), (0.0, h)], c, sides=10, center=(x, y, 0))
        for k in range(5):
            a = rnd.random() * math.pi * 2
            zz = rnd.random() * 0.7
            rr = r * (1 - zz * 0.6)
            ball(bpy, "Sugar", 0.1 * s + 0.05, (x + rr * math.cos(a), y + rr * math.sin(a), h * zz + 0.1), M(kit, "#FFFFFF"), sides=4, stacks=2)


def taffy_hill(bpy, kit):
    base = M(kit, "#FFB3D9", rough=0.5)
    stripe = M(kit, "#FFFFFF", rough=0.5)
    prof = [(0.0, 0.0), (8.0, 0.0), (7.6, 1.5), (6.2, 3.4), (4.0, 5.0), (1.8, 5.8), (0.0, 6.0)]
    rings(bpy, "Hill", prof, base, sides=16, sx=1.0, sy=0.8)
    # twisted stripes running up the hill
    for k in range(6):
        a0 = 2 * math.pi * k / 6
        pts = []
        for t in range(6):
            z = 0.2 + t * 1.0
            rr = 0
            for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
                if z0 <= z <= z1:
                    rr = r0 + (r1 - r0) * (z - z0) / (z1 - z0)
            a = a0 + t * 0.35
            pts.append(((rr + 0.05) * math.cos(a), (rr + 0.05) * 0.8 * math.sin(a), z))
        polyline(bpy, "Stripes", pts, 0.35, stripe, sides=5)


def lollipop_tree(bpy, kit):
    cyl(bpy, "Stick", 0.35, 7.5, (0, 0, 0), M(kit, "#FFFFFF", rough=0.4), sides=8)
    # swirl disc facing front/back
    cols = ["#FF4FA3", "#FFFFFF", "#FFD23F", "#FFFFFF", "#3EC5FF", "#FFFFFF"]
    for k in range(6):
        r0, r1 = 3.2 * k / 6, 3.2 * (k + 1) / 6
        verts, faces = [], []
        n = 18
        for i in range(n):
            a = 2 * math.pi * i / n + k * 0.35
            for r in (r0, r1):
                for y in (-0.5, 0.5):
                    verts.append((r * math.cos(a), y, 10.4 + r * math.sin(a)))
        for i in range(n):
            j = (i + 1) % n
            a, b = 4 * i, 4 * j
            faces.append((a, b, b + 2, a + 2))  # front ring face (y -0.5)
            faces.append((a + 1, a + 3, b + 3, b + 1))  # back
            faces.append((a + 2, b + 2, b + 3, a + 3))  # outer rim
            if r0 > 0:
                faces.append((a, a + 1, b + 1, b))
        obj_from(bpy, "Swirl" + str(k % 2 + 1 if cols[k] == "#FFFFFF" else k + 3), verts, faces, M(kit, cols[k], rough=0.3))
    # a bow at the neck
    bow = M(kit, "#7CF25A", rough=0.4)
    for s in (-1, 1):
        cone(bpy, "Bow", 0.6, 1.0, (0, 0, 7.2), bow, sides=4, rot=(0, s * 90, 0), scale=(1, 0.5, 1))


def soda_geyser(bpy, kit):
    rock = M(kit, "#C9A6FF", rough=0.6)
    soda = M(kit, "#9B5CFF", rough=0.1, emit=0.2)
    foam = M(kit, "#FFFFFF", rough=0.4)
    rings(bpy, "Mound", [(0.0, 0.0), (5.5, 0.0), (5.0, 1.5), (3.6, 3.6), (2.6, 5.2), (2.6, 5.4), (0.0, 5.4)], rock, sides=12)
    cyl(bpy, "Soda", 2.2, 0.3, (0, 0, 5.3), soda, sides=12)
    for k in range(7):
        a = 2 * math.pi * k / 7
        ball(bpy, "Foam", 0.75, (2.3 * math.cos(a), 2.3 * math.sin(a), 5.6), foam, sides=6, stacks=3)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        stick(bpy, "Drips", (3.0 * math.cos(a), 3.0 * math.sin(a), 4.6), (4.3 * math.cos(a), 4.3 * math.sin(a), 2.4), 0.35, soda, sides=5)


def frosted_peak(bpy, kit):
    rock = M(kit, "#B98CFF", rough=0.7)
    frost = M(kit, "#FFFFFF", rough=0.35)
    prof = [(0.0, 0.0), (8.5, 0.0), (7.2, 3.0), (5.2, 7.0), (3.0, 11.0), (1.0, 14.0), (0.0, 15.0)]
    rings(bpy, "Rock", prof, rock, sides=9)
    cap = [(0.0, 8.6), (4.25, 8.6), (3.05, 11.0), (1.05, 14.05), (0.0, 15.12)]
    rings(bpy, "Frost", cap, frost, sides=9, scale=(1.03, 1.03, 1))
    for k in range(9):
        a = 2 * math.pi * (k + 0.5) / 9 + math.pi / 9
        r = 4.25
        ball(bpy, "Frost", 0.8, (r * math.cos(a) * 1.0, r * math.sin(a) * 1.0, 8.3), frost, scale=(1, 1, 1.6), sides=6, stacks=3)
    rnd = random.Random(3)
    cols = ["#FF4FA3", "#FFD23F", "#7CF25A", "#3EC5FF"]
    for k in range(14):
        a = rnd.random() * math.pi * 2
        z = 9.5 + rnd.random() * 4
        r = 3.05 - (z - 11.0) * 0.66 if z > 11 else 4.25 - (z - 8.6) * 0.5
        stick(bpy, "Sprinkles", (r * math.cos(a), r * math.sin(a), z), ((r + 0.05) * math.cos(a + 0.08), (r + 0.05) * math.sin(a + 0.08), z + 0.4), 0.12,
              M(kit, cols[k % 4]), sides=4)


def cloud(bpy, kit):
    w = M(kit, "#FFFFFF", rough=0.6)
    for x, y, z, r in ((0, 0, 1.8, 2.6), (-2.8, 0.3, 1.3, 2.0), (2.9, -0.2, 1.4, 2.1), (-1.2, -0.8, 2.8, 1.8), (1.4, 0.6, 3.0, 1.7), (-4.6, 0, 0.9, 1.3), (4.7, 0.2, 1.0, 1.3)):
        ball(bpy, "Cloud", r, (x, y, z), w, scale=(1, 0.8, 0.8), sides=10, stacks=5)


def rainbow_arch(bpy, kit):
    cols = ["#FF4FA3", "#FF8A3D", "#FFD23F", "#7CF25A", "#3EC5FF", "#9B5CFF"]
    R0, band, th = 92.0, 7.0, 6.0
    n = 32
    for k, c in enumerate(cols):
        r_out = R0 + band * (len(cols) - k)
        r_in = r_out - band
        verts, faces = [], []
        for i in range(n + 1):
            a = math.pi * i / n
            for r in (r_in, r_out):
                for y in (-th / 2, th / 2):
                    verts.append((r * math.cos(a), y, r * math.sin(a)))
        for i in range(n):
            a, b = 4 * i, 4 * (i + 1)
            faces.append((a, b, b + 1, a + 1))  # inner
            faces.append((a + 2, a + 3, b + 3, b + 2))  # outer
            faces.append((a, a + 2, b + 2, b))  # front
            faces.append((a + 1, b + 1, b + 3, a + 3))  # back
        faces.append((0, 1, 3, 2))
        e = 4 * n
        faces.append((e, e + 2, e + 3, e + 1))
        obj_from(bpy, "Band" + str(k + 1), verts, faces, M(kit, c, rough=0.35, emit=0.15))
    # cloud feet
    w = M(kit, "#FFFFFF", rough=0.6)
    for s in (-1, 1):
        cx = s * (R0 + band * 3)
        for dx, dy, dz, r in ((0, 0, 4, 12), (-9, 4, 2, 9), (9, -3, 2, 9), (0, -7, 6, 8)):
            ball(bpy, "Clouds", r, (cx + dx, dy, dz), w, scale=(1, 0.8, 0.7), sides=10, stacks=5)


# ------------------------------------------------------------------ hub stalls
def stall_base(bpy, kit, roof_a, roof_b):
    """A candy kiosk: counter at the front, back wall, striped awning. ~12 wide, ~10 tall."""
    counter = M(kit, "#FFFFFF", rough=0.45)
    trim = M(kit, roof_a, rough=0.45)
    box(bpy, kit, "Counter", 11.0, 2.4, 3.2, 0, -2.4, 0, counter, 0.2)
    box(bpy, kit, "CounterTop", 11.6, 2.9, 0.4, 0, -2.4, 3.2, trim, 0.12)
    box(bpy, kit, "Back", 11.0, 0.8, 9.0, 0, 2.6, 0, M(kit, "#FFE3F1", rough=0.5))
    for s in (-1, 1):
        cyl(bpy, "Posts", 0.4, 9.0, (s * 5.4, -3.4, 0), trim, sides=8)
    # striped awning: alternating wedges
    n = 8
    for i in range(n):
        x0 = -6.2 + 12.4 * i / n
        x1 = -6.2 + 12.4 * (i + 1) / n
        verts = [(x0, -4.6, 8.6), (x1, -4.6, 8.6), (x1, 3.0, 10.4), (x0, 3.0, 10.4),
                 (x0, -4.6, 8.9), (x1, -4.6, 8.9), (x1, 3.0, 10.7), (x0, 3.0, 10.7)]
        faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        obj_from(bpy, "AwningA" if i % 2 == 0 else "AwningB", verts, faces, M(kit, roof_a if i % 2 == 0 else roof_b, rough=0.45))
    # scalloped awning edge
    for i in range(n):
        x = -6.2 + 12.4 * (i + 0.5) / n
        ball(bpy, "AwningA" if i % 2 == 0 else "AwningB", 0.78, (x, -4.6, 8.6), M(kit, roof_a if i % 2 == 0 else roof_b, rough=0.45),
             scale=(1, 0.3, 0.7), sides=8, stacks=3)


def goo_lab(bpy, kit):
    stall_base(bpy, kit, "#7CF25A", "#FFFFFF")
    glass = M(kit, "#E6F7FF", rough=0.1)
    cols = ["#FF4FA3", "#7CF25A", "#3EC5FF", "#FFD23F"]
    for i, x in enumerate((-3.6, -1.2, 1.2, 3.6)):
        z0 = 3.6
        rings(bpy, "Flasks", [(0.0, 0.0), (0.9, 0.0), (1.0, 0.6), (0.7, 1.3), (0.3, 1.7), (0.3, 2.4), (0.0, 2.4)], glass, sides=8, center=(x, -2.4, z0))
        rings(bpy, "Goo" + str(i + 1), [(0.0, 0.05), (0.88, 0.05), (0.95, 0.6), (0.72, 1.1), (0.0, 1.1)], M(kit, cols[i], rough=0.2, emit=0.3), sides=8,
              center=(x, -2.4, z0), scale=(1.04, 1.04, 1))
        for k in range(2):
            ball(bpy, "Goo" + str(i + 1), 0.22 - 0.06 * k, (x + 0.1 * k, -2.4, z0 + 2.7 + 0.5 * k), M(kit, cols[i], rough=0.2, emit=0.3), sides=6, stacks=3)
    # big goo vat on the back wall
    cyl(bpy, "Vat", 2.0, 3.6, (0, 1.2, 3.6), M(kit, "#C9A6FF", rough=0.4), sides=12)
    cyl(bpy, "VatGoo", 1.85, 0.3, (0, 1.2, 7.1), M(kit, "#FF4FA3", rough=0.2, emit=0.4), sides=12)
    polyline(bpy, "Pipes", [(2.0, 1.2, 6.0), (3.4, 1.2, 6.0), (3.4, 1.2, 4.0)], 0.25, M(kit, "#9B5CFF"), sides=6)


def glove_stand(bpy, kit):
    stall_base(bpy, kit, "#3EC5FF", "#FFFFFF")
    glove = M(kit, "#FF8A3D", rough=0.5)
    cuff = M(kit, "#FFFFFF", rough=0.5)
    # a giant boxing-glove sign on the awning
    gz = 12.2
    ball(bpy, "Glove", 1.9, (0, 0.0, gz), glove, scale=(1.1, 0.9, 1.0), sides=12, stacks=6)
    ball(bpy, "Glove", 0.8, (-1.8, -0.4, gz + 0.3), glove, scale=(0.8, 0.8, 1.1), sides=8, stacks=4)
    cyl(bpy, "Cuff", 1.3, 1.4, (1.9, 0, gz - 0.6), cuff, sides=10, rot=(0, 90, 0))
    # small gloves on the counter
    for i, x in enumerate((-3.4, 0.0, 3.4)):
        c = ["#7CF25A", "#FF4FA3", "#FFD23F"][i]
        ball(bpy, "Gloves" + str(i + 1), 0.8, (x, -2.4, 4.4), M(kit, c, rough=0.5), scale=(1.1, 0.9, 1.0), sides=8, stacks=4)
        ball(bpy, "Gloves" + str(i + 1), 0.36, (x - 0.75, -2.6, 4.6), M(kit, c, rough=0.5), sides=6, stacks=3)
        cyl(bpy, "Cuffs", 0.5, 0.5, (x + 0.75, -2.4, 4.4), cuff, sides=8, rot=(0, 90, 0))


def resquish_machine(bpy, kit):
    body = M(kit, "#9B5CFF", rough=0.4)
    trim = M(kit, "#FFD23F", rough=0.3, metal=0.4)
    # chunky press machine: base, press body, funnel on top, big crank, glowing window
    box(bpy, kit, "Base", 10.0, 7.0, 1.4, 0, 0, 0, M(kit, "#FF4FA3", rough=0.45), 0.2)
    box(bpy, kit, "Body", 8.0, 6.0, 7.0, 0, 0.3, 1.4, body, 0.5)
    rings(bpy, "Funnel", [(0.0, 0.0), (1.5, 0.0), (1.5, 1.0), (3.4, 3.2), (3.6, 3.4), (0.0, 3.4)], trim, sides=12, center=(0, 0.3, 8.3))
    cyl(bpy, "FunnelGoo", 3.3, 0.2, (0, 0.3, 11.6), M(kit, "#FF4FA3", rough=0.2, emit=0.4), sides=12)
    # window with a swirl
    box(bpy, kit, "Window", 4.6, 0.3, 3.4, 0, -2.85, 3.4, M(kit, "#7FD3FF", rough=0.05, emit=0.4), 0.3)
    star(bpy, "Swirl", 1.1, (0, -3.05, 5.1), M(kit, "#FFFFFF", emit=0.6), thick=0.15)
    # crank on the right side
    stick(bpy, "Crank", (4.0, 0.3, 5.0), (5.4, 0.3, 5.0), 0.3, trim, sides=8)
    stick(bpy, "Crank", (5.4, 0.3, 5.0), (5.4, 0.3, 7.2), 0.25, trim, sides=8)
    ball(bpy, "Knob", 0.55, (5.4, 0.3, 7.4), M(kit, "#FF4FA3", rough=0.3), sides=8, stacks=4)
    # output chute + lights
    rings(bpy, "Chute", [(0.0, 0.0), (1.4, 0.0), (1.4, 1.0), (0.0, 1.0)], trim, sides=10, center=(-2.6, -3.0, 1.0), rot=(90, 0, 0), scale=(1, 1, 1))
    for i, x in enumerate((-2.8, -1.4, 0.0, 1.4, 2.8)):
        c = ["#FF4FA3", "#FFD23F", "#7CF25A", "#3EC5FF", "#FF8A3D"][i]
        ball(bpy, "Lights" + str(i + 1), 0.3, (x, -2.75, 7.6), M(kit, c, emit=1.2), sides=6, stacks=3)


# ------------------------------------------------------------------ shelf level decor
# Built in shelf coordinates with the shelf's footprint pins, so placing them with the shelf's
# CFrame lines them up (Assets:place pivots at the bounding box's bottom centre).
def shelf_lights(bpy, kit):
    """Level 2: a string of glowing gumdrop lights draped across the top of the shelf."""
    half = SHELF["half"] + 0.9
    wire = M(kit, "#2B1B4A", rough=0.6)
    cols = ["#FF4FA3", "#FFD23F", "#7CF25A", "#3EC5FF", "#9B5CFF"]
    pts = []
    n = 16
    for k in range(n + 1):
        x = -half + 2 * half * k / n
        u = x / half
        pts.append((x, -1.0 + 1.6 * (1 - u * u), 9.5 - 1.1 * (1 - u * u)))
    polyline(bpy, "Wire", pts, 0.07, wire, sides=4)
    for k in range(1, n):
        x, y, z = pts[k]
        mat = M(kit, cols[k % len(cols)], rough=0.3, emit=1.5)
        rings(bpy, "Bulbs", [(0.0, 0.0), (0.46, 0.0), (0.41, 0.34), (0.2, 0.64), (0.0, 0.7)], mat, sides=8,
              center=(x, y, z - 0.8))
    pins_box(bpy, kit, (-SHELF["half"] - 1.5, -5.0, 0.0), (SHELF["half"] + 1.5, 5.0, 10.6))


def star_topper(bpy, kit):
    """Level 4: a puffy gold star on a candy stick above the shelf (the client spins it)."""
    gold = M(kit, "#FFD23F", rough=0.35, emit=0.4)
    stick(bpy, "Stick", (0, 0.4, 8.8), (0, 0.4, 11.0), 0.22, M(kit, "#FF4FA3", rough=0.45), sides=8)
    star(bpy, "Star", 1.9, (0, 0.4, 12.6), gold, thick=0.7)
    ball(bpy, "Star", 0.55, (0, 0.05, 12.6), gold, scale=(1, 0.5, 1), sides=8, stacks=4)
    for s in (-1, 1):
        star(bpy, "Sparkles", 0.4, (s * 2.4, 0.4, 13.6), M(kit, "#FFFFFF", emit=0.8), thick=0.12)
    pins_box(bpy, kit, (-SHELF["half"] - 1.5, -5.0, 0.0), (SHELF["half"] + 1.5, 5.0, 14.8))
