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
