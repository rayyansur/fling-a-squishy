"""Upgrade icons: one per tier, so every row in the Upgrades panel has its own picture.

goo_1..6      a glossy goo drop in the goo's colour, each with its own garnish
sling_1..6    the slingshot tiers (same themes as art/models/_world.py SLING_THEMES)
gloves_1..6   a chunky glove per tier (1 = bare hand)
slots         the shelf with a big plus
shelf_2..5    shelf levels: gumdrop lights, lollipop pillars, star topper, rainbow arch
"""
import math
import os
import sys

from icon_kit import icon

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
import _squishy as S  # noqa: E402

RAINBOW = ["#FF4FA3", "#FF8A3D", "#FFD23F", "#7CF25A", "#3EC5FF", "#9B5CFF"]


# ------------------------------------------------------------------------------------- goo
DROP = [(0.0, 0.0), (0.85, 0.08), (1.12, 0.5), (1.08, 0.95), (0.8, 1.45), (0.45, 1.9), (0.15, 2.3), (0.0, 2.45)]


def _drop(bpy, kit, color, emit=0.15):
    m = S.M(kit, color, rough=0.15, emit=emit)
    S.rings(bpy, "Goo", DROP, m, sides=14, smooth=True)
    # highlight
    S.ball(bpy, "Shine", 0.18, (-0.45, -0.85, 1.35), S.M(kit, "#FFFFFF", emit=0.6), scale=(1, 0.5, 1.6), sides=8, stacks=4)
    # a little face, like the squishies
    eye = S.M(kit, "#2B1B4A")
    for s in (-1, 1):
        S.ball(bpy, "Eyes", 0.12, (s * 0.32, -1.0, 0.85), eye, sides=8, stacks=4)
    return m


def _goo(tier):
    def build(bpy, kit):
        if tier == 1:  # Bubblegum: a big bubble blown off the top
            _drop(bpy, kit, "#FF4FA3")
            S.ball(bpy, "Bubble", 0.75, (0.75, -0.2, 2.45), S.M(kit, "#FFB3D9", rough=0.1), sides=12, stacks=6)
        elif tier == 2:  # Lime Slime: drips running down
            m = _drop(bpy, kit, "#7CF25A")
            for x, z, h in ((-0.95, 0.35, 0.55), (0.9, 0.25, 0.75), (0.2, -0.05, 0.45)):
                S.stick(bpy, "Drips", (x, -0.35, z), (x, -0.35, z - h), 0.16, m, sides=8)
                S.ball(bpy, "Drips", 0.22, (x, -0.35, z - h), m, sides=8, stacks=4)
        elif tier == 3:  # Blue Raspberry: a raspberry on top
            _drop(bpy, kit, "#3EC5FF")
            berry = S.M(kit, "#2F6BFF", rough=0.3)
            for k in range(7):
                a = 2 * math.pi * k / 7
                S.ball(bpy, "Berry", 0.24, (0.6 + 0.25 * math.cos(a), -0.2 + 0.25 * math.sin(a), 2.35 + 0.1 * (k % 2)), berry, sides=8, stacks=4)
            S.ball(bpy, "Berry", 0.24, (0.6, -0.2, 2.62), berry, sides=8, stacks=4)
        elif tier == 4:  # Grape Gel: a grape bunch beside it
            _drop(bpy, kit, "#9B5CFF")
            grape = S.M(kit, "#6A2FD8", rough=0.25)
            for x, z in ((1.0, 1.7), (1.35, 1.65), (1.15, 1.35), (1.5, 1.35), (1.3, 1.05), (1.05, 2.0)):
                S.ball(bpy, "Grapes", 0.25, (x, -0.4, z), grape, sides=8, stacks=4)
            S.stick(bpy, "Stem", (1.15, -0.4, 2.15), (1.0, -0.4, 2.5), 0.06, S.M(kit, "#4DB52E"), sides=5)
        elif tier == 5:  # Lemon Fizz: a lemon slice and fizz bubbles
            _drop(bpy, kit, "#FFD23F")
            S.cyl(bpy, "Lemon", 0.75, 0.2, (0.9, -0.2, 2.0), S.M(kit, "#FFF6A8"), sides=16, rot=(90, 0, 25))
            S.cyl(bpy, "Peel", 0.82, 0.16, (0.9, -0.18, 2.0), S.M(kit, "#FFC21F"), sides=16, rot=(90, 0, 25))
            fizz = S.M(kit, "#FFFFFF", rough=0.1, emit=0.3)
            for x, z, r in ((-0.9, 2.3, 0.14), (-0.6, 2.75, 0.1), (-1.1, 2.9, 0.08), (-0.3, 3.0, 0.12)):
                S.ball(bpy, "Fizz", r, (x, -0.3, z), fizz, sides=8, stacks=4)
        else:  # Rainbow Goo: rainbow bands and a star
            for k, col in enumerate(RAINBOW):
                lo, hi = DROP[min(k, len(DROP) - 2)], DROP[min(k + 1, len(DROP) - 1)]
                S.rings(bpy, "Band" + str(k), [(0.0, lo[1]), (lo[0], lo[1]), (hi[0], hi[1]), (0.0, hi[1])], S.M(kit, col, rough=0.15, emit=0.15), sides=14)
            S.rings(bpy, "Tip", [(0.0, 2.3), (0.15, 2.3), (0.0, 2.45)], S.M(kit, RAINBOW[-1]), sides=10)
            S.ball(bpy, "Shine", 0.18, (-0.45, -0.85, 1.35), S.M(kit, "#FFFFFF", emit=0.6), scale=(1, 0.5, 1.6), sides=8, stacks=4)
            for side in (-1, 1):
                S.ball(bpy, "Eyes", 0.12, (side * 0.32, -1.02, 0.85), S.M(kit, "#2B1B4A"), sides=8, stacks=4)
            S.star(bpy, "Star", 0.6, (0.95, -0.4, 2.35), S.M(kit, "#FFD23F", emit=0.6), thick=0.18)
    return build


for _t in range(1, 7):
    icon("goo_%d" % _t, view=(12, -20))(_goo(_t))


# ------------------------------------------------------------------------------- slingshots
def _fork(bpy, kit, mats, r=0.22):
    """Y fork; mats = colours cycled along the stick (candy-cane stripes when 2)."""
    segs = [((0, 0, 0), (0, 0, 0.5)), ((0, 0, 0.5), (0, 0, 1.0)), ((0, 0, 1.0), (0, 0, 1.4))]
    for s in (-1, 1):
        a, b = (0, 0, 1.4), (s * 0.8, 0, 2.6)
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        segs += [(a, mid), (mid, b)]
    for k, (a, b) in enumerate(segs):
        S.stick(bpy, "Fork" + str(k % len(mats)), a, b, r, mats[k % len(mats)], sides=8)
    S.ball(bpy, "Fork0", r * 1.1, (0, 0, 1.4), mats[0], sides=8, stacks=4)
    # the band
    S.polyline(bpy, "Band", [(-0.8, -0.05, 2.55), (0, -0.45, 1.9), (0.8, -0.05, 2.55)], 0.07, S.M(kit, "#FF4FA3"), sides=5)
    S.ball(bpy, "Pouch", 0.22, (0, -0.45, 1.9), S.M(kit, "#C2185B"), sides=8, stacks=4)


def _sling(tier):
    def build(bpy, kit):
        tips = []
        if tier == 1:  # Candy Cane
            _fork(bpy, kit, [S.M(kit, "#FFFFFF"), S.M(kit, "#FF3B5C")])
            tips = [("ball", "#FF3B5C")]
        elif tier == 2:  # Gummy
            _fork(bpy, kit, [S.M(kit, "#7CF25A", rough=0.15)], r=0.26)
            tips = [("ball", "#FF8A3D")]
        elif tier == 3:  # Lollipop swirl
            _fork(bpy, kit, [S.M(kit, "#3EC5FF")])
            tips = [("lolly", "#FF4FA3")]
        elif tier == 4:  # Choco-Cherry
            _fork(bpy, kit, [S.M(kit, "#7A4A2A", rough=0.4)], r=0.25)
            tips = [("cherry", "#E0123A")]
        elif tier == 5:  # Rock Candy
            _fork(bpy, kit, [S.M(kit, "#9FE3FF", rough=0.1)])
            tips = [("crystal", "#3EC5FF")]
        else:  # Rainbow Star
            _fork(bpy, kit, [S.M(kit, c) for c in RAINBOW])
            tips = [("star", "#FFD23F")]
        kind, col = tips[0]
        m = S.M(kit, col, emit=0.3 if kind in ("star", "crystal") else 0.0, rough=0.2)
        for s in (-1, 1):
            p = (s * 0.8, 0, 2.7)
            if kind == "ball":
                S.ball(bpy, "Tips", 0.28, p, m, sides=8, stacks=4)
            elif kind == "lolly":
                S.cyl(bpy, "Tips", 0.42, 0.14, (p[0], 0.07, p[2] + 0.2), m, sides=14, rot=(90, 0, 0))
                S.cyl(bpy, "Swirl", 0.26, 0.16, (p[0], 0.0, p[2] + 0.2), S.M(kit, "#FFFFFF"), sides=12, rot=(90, 0, 0))
            elif kind == "cherry":
                S.ball(bpy, "Tips", 0.3, p, m, sides=10, stacks=5)
                S.stick(bpy, "Stem", (p[0], 0, p[2] + 0.25), (p[0] + s * 0.2, 0, p[2] + 0.65), 0.05, S.M(kit, "#4DB52E"), sides=5)
            elif kind == "crystal":
                for k, (dx, dz, h) in enumerate(((0, 0, 0.7), (0.2, -0.1, 0.45), (-0.2, -0.05, 0.5))):
                    S.cone(bpy, "Tips", 0.18, h, (p[0] + dx, 0, p[2] - 0.15 + dz), m, sides=6, rot=(0, -s * 15 * (k - 1), 0))
            else:
                S.star(bpy, "Tips", 0.38, (p[0], -0.1, p[2] + 0.1), m, thick=0.14)
        if tier == 4:  # sprinkles on the chocolate
            for k, (x, z) in enumerate(((0.1, 0.6), (-0.1, 1.0), (0.35, 1.8), (-0.4, 1.9), (0.05, 0.25))):
                S.stick(bpy, "Sprinkles" + str(k % 3), (x - 0.08, -0.24, z), (x + 0.08, -0.24, z + 0.06), 0.04, S.M(kit, RAINBOW[k % 6]), sides=4)
    return build


for _t in range(1, 7):
    icon("sling_%d" % _t, view=(16, -24))(_sling(_t))


# ----------------------------------------------------------------------------------- gloves
def _hand(bpy, kit, m, cuff=None):
    # palm
    S.rings(bpy, "Palm", [(0.0, 0.0), (0.75, 0.05), (0.85, 0.6), (0.8, 1.2), (0.0, 1.25)], m, sx=1.0, sy=0.55, n=3.0, sides=14)
    # fingers
    for k, (x, h) in enumerate(((-0.55, 0.85), (-0.18, 1.0), (0.18, 0.95), (0.52, 0.8))):
        S.stick(bpy, "Fingers", (x, 0, 1.1), (x * 1.08, 0, 1.1 + h), 0.2, m, sides=8)
        S.ball(bpy, "Fingers", 0.2, (x * 1.08, 0, 1.1 + h), m, sides=8, stacks=4)
    # thumb
    S.stick(bpy, "Thumb", (0.7, 0, 0.6), (1.2, 0, 1.15), 0.21, m, sides=8)
    S.ball(bpy, "Thumb", 0.21, (1.2, 0, 1.15), m, sides=8, stacks=4)
    if cuff:
        S.cyl(bpy, "Cuff", 0.85, 0.45, (0, 0, -0.35), cuff, sides=14, scale=(1, 0.62, 1))


def _gloves(tier):
    def build(bpy, kit):
        if tier == 1:  # Bare Hands
            _hand(bpy, kit, S.M(kit, "#FFD9B8"))
            return
        cols = {2: "#7CF25A", 3: "#FF4FA3", 4: "#3EC5FF", 5: "#FFD23F", 6: "#FF4FA3"}
        m = S.M(kit, cols[tier], rough=0.25 if tier != 2 else 0.1)
        _hand(bpy, kit, m, cuff=S.M(kit, "#FFFFFF" if tier != 6 else "#9B5CFF"))
        if tier == 3:  # taffy stripes
            for k, z in enumerate((0.3, 0.75)):
                S.cyl(bpy, "Stripes", 0.84, 0.14, (0, 0, z), S.M(kit, "#FFFFFF"), sides=14, scale=(1, 0.58, 1))
        elif tier == 4:  # soda bubbles
            fizz = S.M(kit, "#FFFFFF", rough=0.1, emit=0.3)
            for x, z, r in ((-1.1, 1.6, 0.16), (-1.3, 2.1, 0.11), (-0.95, 2.45, 0.09)):
                S.ball(bpy, "Fizz", r, (x, -0.3, z), fizz, sides=8, stacks=4)
        elif tier == 5:  # sprinkles
            for k, (x, z) in enumerate(((-0.4, 0.4), (0.3, 0.3), (0.0, 0.8), (-0.5, 0.95), (0.45, 0.85), (0.1, 0.15))):
                S.stick(bpy, "Sprinkles" + str(k % 3), (x - 0.1, -0.48, z), (x + 0.1, -0.48, z + 0.08), 0.05, S.M(kit, RAINBOW[(k * 2) % 6]), sides=4)
        elif tier == 6:  # rainbow fingers + star
            for k, (x, h) in enumerate(((-0.55, 0.85), (-0.18, 1.0), (0.18, 0.95), (0.52, 0.8))):
                S.ball(bpy, "Tipcols" + str(k), 0.215, (x * 1.08, 0, 1.1 + h), S.M(kit, RAINBOW[k + 1]), sides=8, stacks=4)
            S.star(bpy, "Star", 0.45, (0, -0.5, 0.6), S.M(kit, "#FFD23F", emit=0.6), thick=0.16)
    return build


for _t in range(1, 7):
    icon("gloves_%d" % _t, view=(10, -18))(_gloves(_t))


# ------------------------------------------------------------------------------------ shelf
def _shelf(bpy, kit, tiers=3):
    board = S.M(kit, "#FFB3D9")
    lip = S.M(kit, "#FF4FA3")
    for k in range(tiers):
        kit.box("Boards", 3.2, 0.9, 0.25, 0, 0.6 * k, 1.1 * k, board)
        kit.box("Lips", 3.3, 0.2, 0.35, 0, 0.6 * k - 0.5, 1.1 * k - 0.05, lip)
    cols = ["#7CF25A", "#3EC5FF", "#FFD23F", "#9B5CFF", "#FF8A3D"]
    i = 0
    rows = ((-1.0, 0.0, 1.0), (-0.5, 0.5), (0.0,), (0.0,))[:tiers]
    for k, xs in enumerate(rows):
        for x in xs:
            S.ball(bpy, "Squishy" + str(i % 5 + 1), 0.38, (x, 0.6 * k, 1.1 * k + 0.55), S.M(kit, cols[i % 5]), scale=(1, 1, 0.85), sides=10, stacks=5)
            i += 1
    return 1.1 * (tiers - 1) + 0.3  # top surface height


@icon("slots", view=(16, -24))
def slots(bpy, kit):
    _shelf(bpy, kit)
    g = S.M(kit, "#4DB52E", emit=0.2)
    kit.box("Plus", 1.3, 0.35, 0.38, 1.55, -0.9, 2.6, g, bevel=0.06)
    kit.box("Plus", 0.38, 0.35, 1.3, 1.55, -0.9, 2.15, g, bevel=0.06)


def _shelf_level(level):
    def build(bpy, kit):
        tiers = 4 if level >= 4 else 3
        top = _shelf(bpy, kit, tiers)
        back = 0.6 * (tiers - 1)
        if level >= 2:  # gumdrop lights along the top
            for k, x in enumerate((-1.4, -0.7, 0.0, 0.7, 1.4)):
                S.ball(bpy, "Lights" + str(k % 3), 0.2, (x, back, top + 0.15), S.M(kit, ["#FFD23F", "#7CF25A", "#3EC5FF"][k % 3], emit=0.7), scale=(1, 1, 0.8), sides=8, stacks=4)
        if level >= 3:  # lollipop pillars
            for s in (-1, 1):
                S.stick(bpy, "Pillars", (s * 1.85, 0, -0.1), (s * 1.85, 0, top + 0.6), 0.1, S.M(kit, "#FFFFFF"), sides=6)
                S.cyl(bpy, "Pops", 0.38, 0.14, (s * 1.85, 0.07, top + 0.85), S.M(kit, "#9B5CFF"), sides=14, rot=(90, 0, 0))
                S.cyl(bpy, "Swirl", 0.22, 0.16, (s * 1.85, 0.0, top + 0.85), S.M(kit, "#FFFFFF"), sides=12, rot=(90, 0, 0))
        if level >= 4:  # star topper (sits on the arch at level 5)
            sz = top + (1.75 if level >= 5 else 0.85)
            S.star(bpy, "Star", 0.55, (0, back - 0.3, sz), S.M(kit, "#FFD23F", emit=0.6), thick=0.18)
        if level >= 5:  # rainbow arch over the whole shelf
            for k, col in enumerate(RAINBOW):
                r = 2.9 - k * 0.15
                pts = [(r * math.cos(math.radians(a)), back + 0.3, top - 1.2 + r * math.sin(math.radians(a))) for a in range(0, 181, 15)]
                S.polyline(bpy, "Arch" + str(k), pts, 0.08, S.M(kit, col, emit=0.2), sides=5)
    return build


for _l in range(2, 6):
    icon("shelf_%d" % _l, view=(16, -24))(_shelf_level(_l))
