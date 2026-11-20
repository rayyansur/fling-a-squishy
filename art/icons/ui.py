"""Fling a Squishy UI icons: chunky candy objects, bright and readable at 40 px."""
import math
import os
import sys

from icon_kit import icon

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import _squishy as S  # noqa: E402


@icon("coin", view=(14, -18))
def coin(bpy, kit):
    gold = kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    dark = kit.mat("golddark", "#E8A400", rough=0.3, metal=0.5)
    o = kit.cylinder("Coin", 1.0, 0.28, -0.14, verts=24, mat=gold, bevel=0.06)
    o.rotation_euler = (math.radians(90), 0, 0)
    S.star(bpy, "Star", 0.5, (0, -0.16, 0), dark, thick=0.06, rot=(90, 0, 0))


@icon("squishy", view=(10, -20))
def squishy(bpy, kit):
    m = S.M(kit, "#FFB3D9")
    S.body_mesh(bpy, "bun", m)
    S.face(bpy, kit, "bun")


@icon("sp", view=(16, -24))
def sp(bpy, kit):
    # a slingshot fork with a glowing star: Sling Power
    wood = S.M(kit, "#FF4FA3")
    S.stick(bpy, "Frame", (0, 0, 0), (0, 0, 1.4), 0.22, wood, sides=8)
    for s in (-1, 1):
        S.stick(bpy, "Frame", (0, 0, 1.4), (s * 0.8, 0, 2.6), 0.2, wood, sides=8)
        S.ball(bpy, "Tips", 0.24, (s * 0.8, 0, 2.65), S.M(kit, "#FFD23F"), sides=8, stacks=4)
    S.ball(bpy, "Frame", 0.24, (0, 0, 1.4), wood, sides=8, stacks=4)
    S.star(bpy, "Star", 0.55, (0.95, -0.3, 1.2), S.M(kit, "#FFD23F", emit=0.6), thick=0.18)


@icon("upgrades", view=(14, -22))
def upgrades(bpy, kit):
    # a bubbling goo flask
    glass = S.M(kit, "#E6F7FF", rough=0.1)
    S.rings(bpy, "Flask", [(0.0, 0.0), (1.0, 0.0), (1.1, 0.6), (0.8, 1.4), (0.35, 1.9), (0.35, 2.6), (0.0, 2.6)], glass, sides=12)
    S.rings(bpy, "Goo", [(0.0, 0.02), (1.02, 0.02), (1.12, 0.6), (0.85, 1.2), (0.0, 1.2)], S.M(kit, "#7CF25A", emit=0.3), sides=12, scale=(1.03, 1.03, 1))
    S.ball(bpy, "Bubble", 0.22, (0.05, 0, 2.95), S.M(kit, "#7CF25A", emit=0.3), sides=8, stacks=4)
    S.ball(bpy, "Bubble", 0.14, (0.25, 0, 3.35), S.M(kit, "#7CF25A", emit=0.3), sides=8, stacks=4)
    S.cone(bpy, "Arrow", 0.55, 0.7, (1.15, -0.2, 1.6), S.M(kit, "#FF4FA3"), sides=4)
    S.cyl(bpy, "Arrow", 0.2, 0.7, (1.15, -0.2, 0.9), S.M(kit, "#FF4FA3"), sides=6)


@icon("shelf", view=(16, -24))
def shelf(bpy, kit):
    board = S.M(kit, "#FFB3D9")
    lip = S.M(kit, "#FF4FA3")
    for k in range(3):
        kit.box("Boards", 3.2, 0.9, 0.25, 0, 0.6 * k, 1.1 * k, board)
        kit.box("Lips", 3.3, 0.2, 0.35, 0, 0.6 * k - 0.5, 1.1 * k - 0.05, lip)
    cols = ["#7CF25A", "#3EC5FF", "#FFD23F", "#9B5CFF", "#FF8A3D"]
    i = 0
    for k, xs in enumerate(((-1.0, 0.0, 1.0), (-0.5, 0.5), (0.0,))):
        for x in xs:
            S.ball(bpy, "Squishy" + str(i % 5 + 1), 0.38, (x, 0.6 * k, 1.1 * k + 0.55), S.M(kit, cols[i % 5]), scale=(1, 1, 0.85), sides=10, stacks=5)
            i += 1


@icon("shop", view=(14, -22))
def shop(bpy, kit):
    bag = S.M(kit, "#9B5CFF")
    kit.box("Bag", 2.0, 1.2, 2.2, 0, 0, 0, bag, bevel=0.15)
    S.polyline(bpy, "Handle", [(-0.5, 0, 2.1), (-0.45, 0, 2.7), (0.45, 0, 2.7), (0.5, 0, 2.1)], 0.1, S.M(kit, "#FFD23F"), sides=6)
    S.star(bpy, "Star", 0.55, (0, -0.65, 1.1), S.M(kit, "#FFD23F", emit=0.3), thick=0.12)


@icon("dex", view=(12, -20))
def dex(bpy, kit):
    cover = S.M(kit, "#3EC5FF")
    kit.box("Book", 2.2, 0.5, 2.8, 0, 0, 0, cover, bevel=0.1)
    kit.box("Pages", 2.0, 0.42, 2.6, 0.12, 0.02, 0.1, S.M(kit, "#FFFFFF"))
    m = S.M(kit, "#FFB3D9")
    o = S.body_mesh(bpy, "bun", m)
    for v in o.data.vertices:
        v.co = (v.co.x * 0.6, v.co.y * 0.3 - 0.35, v.co.z * 0.6 + 0.9)
    S.star(bpy, "Star", 0.3, (0.65, -0.3, 2.3), S.M(kit, "#FFD23F", emit=0.4), thick=0.08)


@icon("daily", view=(14, -22))
def daily(bpy, kit):
    box = S.M(kit, "#FF4FA3")
    rib = S.M(kit, "#FFD23F")
    kit.box("Gift", 2.0, 2.0, 1.7, 0, 0, 0, box, bevel=0.08)
    kit.box("Lid", 2.2, 2.2, 0.45, 0, 0, 1.7, box, bevel=0.08)
    kit.box("Ribbon", 0.4, 2.25, 2.2, 0, 0, 0, rib)
    kit.box("Ribbon", 2.25, 0.4, 2.2, 0, 0, 0, rib)
    for s in (-1, 1):
        S.cone(bpy, "Bow", 0.4, 0.75, (0, 0, 2.2), rib, sides=4, rot=(0, s * 60, 0), scale=(1, 0.5, 1))


@icon("settings", view=(20, -15))
def settings(bpy, kit):
    g = S.M(kit, "#9B5CFF")
    n = 8
    verts, faces = [], []
    pts = []
    for k in range(n * 4):
        a = 2 * math.pi * k / (n * 4)
        r = 1.25 if (k % 4) in (1, 2) else 0.95
        pts.append((r * math.cos(a), r * math.sin(a)))
    for y in (-0.25, 0.25):
        for x, z in pts:
            verts.append((x, y, z))
    m = len(pts)
    for k in range(m):
        k1 = (k + 1) % m
        faces.append((k, k1, m + k1, m + k))
    faces.append(tuple(range(m - 1, -1, -1)))
    faces.append(tuple(range(m, 2 * m)))
    S.obj_from(bpy, "Gear", verts, faces, g)
    S.cyl(bpy, "Hub", 0.42, 0.62, (0, -0.31, 0), S.M(kit, "#FFD23F"), sides=10, rot=(90, 0, 0))


@icon("resquish", view=(14, -22))
def resquish(bpy, kit):
    m = S.M(kit, "#FFD23F")
    S.body_mesh(bpy, "blob", m)
    S.face(bpy, kit, "blob")
    arrow = S.M(kit, "#9B5CFF")
    pts = []
    for k in range(9):
        a = math.radians(-30 + 250 * k / 8)
        pts.append((1.45 * math.cos(a), -0.2, 0.9 + 1.45 * math.sin(a)))
    S.polyline(bpy, "Arrow", pts, 0.13, arrow, sides=6)
    S.cone(bpy, "Arrow", 0.32, 0.55, pts[0], arrow, sides=6, rot=(0, 160, 0))


# ---------------------------------------------------------------- shop (passes + products)
def _coin(kit, name, x, y, z, r=0.7, tilt=90, gold=None):
    gold = gold or kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    o = kit.cylinder(name, r, r * 0.28, 0, verts=20, mat=gold, bevel=0.05)
    o.rotation_euler = (math.radians(tilt), 0, 0)
    o.location = (x, y, z)
    return o


def _gear(bpy, kit, name, r, center, color="#FFFFFF", rot=(90, 0, 0)):
    """A small flat gear (the 'auto' badge), flat in local XZ when rot=(90,0,0)."""
    n = 8
    pts = []
    for k in range(n * 4):
        a = 2 * math.pi * k / (n * 4)
        rr = r if (k % 4) in (1, 2) else r * 0.76
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    verts, faces = [], []
    for y in (-0.12 * r, 0.12 * r):
        for x, z in pts:
            verts.append((center[0] + x, center[1] + y, center[2] + z))
    m = len(pts)
    for k in range(m):
        k1 = (k + 1) % m
        faces.append((k, k1, m + k1, m + k))
    faces.append(tuple(range(m - 1, -1, -1)))
    faces.append(tuple(range(m, 2 * m)))
    S.obj_from(bpy, name, verts, faces, S.M(kit, color))
    S.cyl(bpy, name + "Hub", r * 0.32, r * 0.3, (center[0], center[1] - 0.16 * r, center[2]), S.M(kit, "#2B1B4A"), sides=10, rot=(90, 0, 0))


@icon("pass_coins", view=(12, -18))
def pass_coins(bpy, kit):
    # two big coins, one behind the other, with a lime "up" arrow: double coins
    gold = kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    dark = kit.mat("golddark", "#E8A400", rough=0.3, metal=0.5)
    _coin(kit, "CoinBack", 0.55, 0.35, 1.35, r=0.95, gold=gold)
    S.star(bpy, "StarBack", 0.45, (0.55, 0.15, 1.35), dark, thick=0.06, rot=(90, 0, 0))
    _coin(kit, "Coin", -0.45, -0.2, 0.95, r=0.95, gold=gold)
    S.star(bpy, "Star", 0.45, (-0.45, -0.4, 0.95), dark, thick=0.06, rot=(90, 0, 0))
    lime = S.M(kit, "#7CF25A")
    S.cyl(bpy, "Arrow", 0.2, 0.9, (1.45, -0.5, 0.2), lime, sides=8)
    S.cone(bpy, "Arrow", 0.5, 0.7, (1.45, -0.5, 1.05), lime, sides=8)


@icon("pass_fling", view=(16, -24))
def pass_fling(bpy, kit):
    # the slingshot with a goo ball flying off it and a white gear: flings by itself
    wood = S.M(kit, "#FF4FA3")
    S.stick(bpy, "Frame", (0, 0, 0), (0, 0, 1.3), 0.22, wood, sides=8)
    for s in (-1, 1):
        S.stick(bpy, "Frame", (0, 0, 1.3), (s * 0.75, 0, 2.4), 0.2, wood, sides=8)
        S.ball(bpy, "Tips", 0.24, (s * 0.75, 0, 2.45), S.M(kit, "#FFD23F"), sides=8, stacks=4)
    S.ball(bpy, "Frame", 0.24, (0, 0, 1.3), wood, sides=8, stacks=4)
    S.ball(bpy, "Goo", 0.5, (0.9, -0.4, 3.3), S.M(kit, "#7CF25A", emit=0.2), sides=12, stacks=6)
    for k, (x, z) in enumerate(((0.35, 2.85), (0.05, 2.6))):
        S.ball(bpy, "Drops", 0.18 - 0.05 * k, (x, -0.4, z), S.M(kit, "#7CF25A", emit=0.2), sides=8, stacks=4)
    _gear(bpy, kit, "Gear", 0.75, (-1.0, -0.6, 0.7))


@icon("pass_squeeze", view=(10, -20))
def pass_squeeze(bpy, kit):
    # a squishy squashed flat, coins popping off it, and the white gear
    m = S.M(kit, "#3EC5FF")
    S.body_mesh(bpy, "bun", m)
    S.face(bpy, kit, "bun")
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            x, y, z = obj.location
            obj.location = (x * 1.25, y * 1.25, z * 0.62)
            obj.scale = (obj.scale[0] * 1.25, obj.scale[1] * 1.25, obj.scale[2] * 0.62)
    gold = kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    _coin(kit, "Coin", -0.9, -0.3, 2.3, r=0.38, gold=gold)
    _coin(kit, "Coin", 0.95, -0.3, 2.55, r=0.32, gold=gold)
    _gear(bpy, kit, "Gear", 0.62, (1.25, -1.2, 0.55))


@icon("pass_rainbow", view=(10, -14))
def pass_rainbow(bpy, kit):
    # a goo ball streaking along a rainbow
    cols = ["#FF4F6E", "#FF9A3D", "#FFE14D", "#7CF25A", "#3EC5FF", "#B36BFF"]
    for k, c in enumerate(cols):
        r = 2.0 - 0.22 * k
        pts = []
        for j in range(13):
            a = math.radians(180 * j / 12)
            pts.append((r * math.cos(a), 0, r * math.sin(a)))
        S.polyline(bpy, "Band" + str(k), pts, 0.12, S.M(kit, c, emit=0.15), sides=6)
    S.ball(bpy, "Goo", 0.55, (1.15, -0.35, 1.6), S.M(kit, "#FF4FA3"), sides=12, stacks=6)
    S.ball(bpy, "Shine", 0.16, (1.0, -0.8, 1.85), S.M(kit, "#FFFFFF", emit=0.3), sides=8, stacks=4)


def _coin_pile(bpy, kit, spots, gold):
    for k, (x, y, z, t) in enumerate(spots):
        _coin(kit, "Pile", x, y, z, r=0.36, tilt=t, gold=gold)


@icon("coin_bag", view=(14, -22))
def coin_bag(bpy, kit):
    sack = S.M(kit, "#C98A4B")
    S.ball(bpy, "Sack", 1.1, (0, 0, 1.05), sack, scale=(1, 1, 0.95), sides=14, stacks=7)
    S.cone(bpy, "Neck", 0.55, 0.5, (0, 0, 1.85), sack, sides=12, r_top=0.32)
    S.cyl(bpy, "Tie", 0.36, 0.14, (0, 0, 2.2), S.M(kit, "#FF4FA3"), sides=12)
    for s in (-1, 1):
        S.ball(bpy, "Flap", 0.3, (s * 0.25, 0, 2.5), sack, scale=(1, 0.6, 1.2), sides=8, stacks=4)
    gold = kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    _coin(kit, "Front", 0, -1.05, 1.0, r=0.5, gold=gold)
    S.star(bpy, "Star", 0.24, (0, -1.25, 1.0), kit.mat("golddark", "#E8A400", rough=0.3, metal=0.5), thick=0.05, rot=(90, 0, 0))


@icon("coin_jar", view=(16, -22))
def coin_jar(bpy, kit):
    # a jar packed with coins: gold up to the shoulder, glass above, a white shine stripe
    gold = kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    dark = kit.mat("golddark", "#E8A400", rough=0.3, metal=0.5)
    S.rings(bpy, "Coins", [(0.0, 0.0), (1.0, 0.0), (1.08, 0.2), (1.08, 1.55), (0.0, 1.55)], gold, sides=16)
    for k in range(4):
        S.rings(bpy, "Edges", [(1.08, 0.3 + 0.32 * k), (1.11, 0.3 + 0.32 * k), (1.11, 0.36 + 0.32 * k), (1.08, 0.36 + 0.32 * k)], dark, sides=16)
    S.rings(bpy, "Glass", [(1.08, 1.55), (1.08, 2.0), (0.85, 2.3), (0.0, 2.3), (0.0, 1.55)], S.M(kit, "#BFE9FF", rough=0.1), sides=16)
    S.cyl(bpy, "Lid", 0.9, 0.35, (0, 0, 2.3), S.M(kit, "#FF4FA3"), sides=16)
    kit.box("Shine", 0.16, 0.05, 1.5, -0.55, -0.92, 0.45, S.M(kit, "#FFFFFF", emit=0.3))
    _coin(kit, "Front", 0.25, -1.12, 0.85, r=0.5, gold=gold)
    S.star(bpy, "Star", 0.24, (0.25, -1.32, 0.85), dark, thick=0.05, rot=(90, 0, 0))


@icon("coin_tub", view=(20, -22))
def coin_tub(bpy, kit):
    tub = S.M(kit, "#9B5CFF")
    S.rings(bpy, "Tub", [(0.0, 0.0), (1.2, 0.0), (1.55, 1.3), (1.65, 1.4), (0.0, 1.4)], tub, sides=16)
    S.rings(bpy, "Rim", [(1.5, 1.3), (1.75, 1.3), (1.75, 1.5), (1.5, 1.5)], S.M(kit, "#FFD23F"), sides=16)
    gold = kit.mat("gold", "#FFC93C", rough=0.3, metal=0.5)
    S.ball(bpy, "Heap", 1.5, (0, 0, 1.3), gold, scale=(1, 1, 0.55), sides=16, stacks=6)
    spots = []
    for k in range(9):
        a = 2 * math.pi * k / 9
        spots.append((1.0 * math.cos(a), 1.0 * math.sin(a), 1.75 + 0.15 * math.sin(3 * a), 60 + 25 * math.cos(2 * a)))
    spots.append((0.0, -0.2, 2.15, 75))
    _coin_pile(bpy, kit, spots, gold)


@icon("party", view=(12, -20))
def party(bpy, kit):
    # a striped party hat on a happy squishy, confetti around it
    m = S.M(kit, "#FFB3D9")
    S.body_mesh(bpy, "blob", m)
    S.face(bpy, kit, "blob")
    top = S.top_of("blob")
    S.cone(bpy, "Hat", 0.55, 1.4, (0.1, 0.05, top - 0.15), S.M(kit, "#FFD23F"), sides=14, rot=(0, 12, 0))
    S.cone(bpy, "HatBand", 0.45, 0.25, (0.12, 0.05, top + 0.2), S.M(kit, "#FF4FA3"), sides=14, rot=(0, 12, 0), r_top=0.4)
    S.ball(bpy, "Pom", 0.22, (0.4, 0.05, top + 1.25), S.M(kit, "#3EC5FF"), sides=8, stacks=4)
    cols = ["#7CF25A", "#3EC5FF", "#9B5CFF", "#FF8A3D", "#FF4FA3"]
    spots = [(-1.5, -0.4, 2.2), (1.6, -0.3, 1.9), (-1.3, -0.5, 0.9), (1.4, -0.6, 0.6), (-0.9, -0.6, 2.9), (1.2, -0.4, 2.9)]
    for k, p in enumerate(spots):
        kit.box("Confetti" + str(k % 5), 0.32, 0.08, 0.18, p[0], p[1], p[2], S.M(kit, cols[k % 5]))
