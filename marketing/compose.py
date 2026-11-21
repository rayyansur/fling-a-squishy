#!/usr/bin/env python3
"""Finish the game page art from the Studio captures in marketing/captures (staged in the real
map with marketing/studio_stage.luau): each shot is a normal capture plus a mask capture from the
same camera (staged things flat white on black). This adds the punch, a white sticker outline
round the avatar and squishies, glows, sparkles, and the loud thumbnail type.

usage: python3 marketing/compose.py      (needs Pillow + numpy; the font ships with Roblox Studio)
writes marketing/thumbnail_1_bounce.png, thumbnail_2_merge.png, thumbnail_3_collect.png
(1920x1080) and marketing/icon.png (512x512)
"""
import colorsys
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

DEST = os.path.dirname(os.path.abspath(__file__))
CAPS = os.path.join(DEST, "captures")
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/LuckiestGuy-Regular.ttf"

INK = (70, 18, 60)  # deep berry, the game's ink
WHITE = (255, 255, 255)
W, H = 1920, 1080


# ---------------------------------------------------------------- the picture

def load(shot, top, zoom=1.0):
    """The capture and its mask, cropped to 16:9 (centred, `zoom` x closer) from `top` (capture
    pixels) and scaled to 1920 wide. Returns them and t = (scale, left, top) for at()/box()."""
    src = Image.open(os.path.join(CAPS, shot + ".jpg")).convert("RGB")
    msk = Image.open(os.path.join(CAPS, shot + "_mask.jpg")).convert("L")
    w, h = src.size
    cw = w / zoom
    ch = cw * 9 / 16
    left = (w - cw) / 2
    top = max(0, min(h - ch, top))
    box = (round(left), round(top), round(left + cw), round(top + ch))
    src = src.crop(box).resize((W, H), Image.LANCZOS)
    msk = msk.crop(box).resize((W, H), Image.LANCZOS)
    return src, clean(msk), (W / cw, left, top)


def clean(m):
    """Mask capture -> a solid alpha: threshold off the stars, close the pinholes, soften 1 px."""
    m = m.point(lambda v: 255 if v > 120 else 0)
    m = m.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(7))  # stars and specks out
    m = m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))  # pinholes closed
    return m.filter(ImageFilter.GaussianBlur(0.8))


def punch(im, color=1.28, contrast=1.08):
    im = ImageEnhance.Color(im).enhance(color)
    im = ImageEnhance.Contrast(im).enhance(contrast)
    return im.filter(ImageFilter.UnsharpMask(radius=2.2, percent=90, threshold=2))


def sticker(im, mask, width=12, src=None):
    """A clean white outline round the masked things (with a faint ink edge outside), then the
    things themselves (from `src`, else from `im` itself) back on top."""
    fg = (src or im).copy()
    fg.putalpha(mask)
    hard = mask.point(lambda v: 255 if v > 60 else 0)
    ink = hard.filter(ImageFilter.MaxFilter(width * 2 + 5)).filter(ImageFilter.GaussianBlur(1.5))
    ink_l = Image.new("RGBA", im.size, INK + (255,))
    ink_l.putalpha(ink.point(lambda v: int(v * 0.4)))
    im.alpha_composite(ink_l)
    big = hard.filter(ImageFilter.MaxFilter(width * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    wl = Image.new("RGBA", im.size, WHITE + (255,))
    wl.putalpha(big)
    im.alpha_composite(wl)
    im.alpha_composite(fg)


def glow(im, box, color, scale=1.0, strength=200):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = max(x1 - x0, y1 - y0) * 0.62 * scale
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=strength)
    m = m.filter(ImageFilter.GaussianBlur(r * 0.35))
    c = Image.new("RGBA", im.size, color + (255,))
    c.putalpha(m)
    im.alpha_composite(c)


def rays(im, center, color=(255, 250, 215), n=16, alpha=80, width_deg=10):
    cx, cy = center
    m = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(m)
    R = 3000
    for k in range(n):
        a0 = math.radians(k * 360 / n)
        a1 = a0 + math.radians(width_deg)
        d.polygon([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))], fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(4))
    c = Image.new("RGBA", im.size, color + (255,))
    c.putalpha(m)
    im.alpha_composite(c)


def streaks(im, alpha=55):
    """Soft light streaks fanning in from the top corners."""
    s = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(s)
    for cx, angs in ((0, (10, 24)), (im.width, (156, 170))):
        for a in angs:
            r, wid = math.radians(a), math.radians(2.0)
            L = im.width * 1.3
            d.polygon([(cx, -40), (cx + L * math.cos(r - wid), -40 + L * math.sin(r - wid)),
                       (cx + L * math.cos(r + wid), -40 + L * math.sin(r + wid))], fill=alpha)
    s = s.filter(ImageFilter.GaussianBlur(6))
    lt = Image.new("RGBA", im.size, WHITE + (255,))
    lt.putalpha(s)
    im.alpha_composite(lt)


def vignette(im, strength=0.35, color=(90, 20, 80)):
    v = Image.new("L", im.size, 0)
    ImageDraw.Draw(v).ellipse((-im.width * 0.16, -im.height * 0.24, im.width * 1.16, im.height * 1.24), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(im.width / 12))
    dark = Image.new("RGBA", im.size, color + (255,))
    dark.putalpha(v.point(lambda p: int((255 - p) * strength)))
    im.alpha_composite(dark)


def sparkle(im, x, y, r, color=WHITE, rot=0):
    """A four-point twinkle with a soft glow."""
    m = Image.new("L", (int(r * 4), int(r * 4)), 0)
    d = ImageDraw.Draw(m)
    c = r * 2
    pts = []
    for k in range(8):
        a = math.radians(rot + k * 45)
        rr = r if k % 2 == 0 else r * 0.22
        pts.append((c + rr * math.cos(a), c + rr * math.sin(a)))
    d.polygon(pts, fill=255)
    m = ImageChops.lighter(m, m.filter(ImageFilter.GaussianBlur(r * 0.25)))
    col = Image.new("RGBA", m.size, color + (255,))
    col.putalpha(m)
    im.alpha_composite(col, (int(x - c), int(y - c)))


def sparkles(im, box, color, n=9, seed=4, rmin=16, rmax=34):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = box
    for i in range(n):
        x = rnd.uniform(x0 - 40, x1 + 40)
        y = rnd.uniform(y0 - 30, y0 + (y1 - y0) * 0.85)
        sparkle(im, x, y, rnd.uniform(rmin, rmax), color if i % 3 else WHITE, rnd.uniform(0, 30))


def splat(im, x, y, r, color, seed=1):
    """A goo splat: a blob with droplets round it, ink outline, a white shine."""
    rnd = random.Random(seed)
    m = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(m)
    d.ellipse((x - r, y - r * 0.85, x + r, y + r * 0.85), fill=255)
    for k in range(7):
        a = rnd.uniform(0, math.tau)
        dist = r * rnd.uniform(0.9, 1.5)
        rr = r * rnd.uniform(0.15, 0.32)
        px, py = x + math.cos(a) * dist, y + math.sin(a) * dist
        d.ellipse((px - rr, py - rr, px + rr, py + rr), fill=255)
        d.line([(x, y), (px, py)], fill=255, width=int(rr * 1.1))
    m = m.filter(ImageFilter.GaussianBlur(1.2))
    o = m.filter(ImageFilter.MaxFilter(9))
    ol = Image.new("RGBA", im.size, INK + (255,))
    ol.putalpha(o)
    im.alpha_composite(ol)
    c = Image.new("RGBA", im.size, color + (255,))
    c.putalpha(m)
    im.alpha_composite(c)
    sh = Image.new("L", im.size, 0)
    ImageDraw.Draw(sh).ellipse((x - r * 0.55, y - r * 0.6, x - r * 0.05, y - r * 0.3), fill=170)
    sh = sh.filter(ImageFilter.GaussianBlur(r * 0.08))
    w = Image.new("RGBA", im.size, WHITE + (255,))
    w.putalpha(sh)
    im.alpha_composite(w)


# ---------------------------------------------------------------- the type

def glyph(ch, size, top, bottom, tilt=0, outline=None, shadow=INK):
    """One letter: a top-to-bottom gradient face, a thin white inner line, a thick ink outline and
    a hard drop shadow (the loud Roblox-thumbnail look)."""
    outline = outline or INK
    font = ImageFont.truetype(FONT, size)
    pad = size // 2
    l, t, r, b = font.getbbox(ch)
    w, h = r - l + pad * 2, b - t + pad * 2
    origin = (pad - l, pad - t)

    def mask(stroke):
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).text(origin, ch, font=font, fill=255, stroke_width=stroke, stroke_fill=255)
        return m

    outer, inner = max(6, size // 9), max(3, size // 30)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    full = mask(outer)
    sh = Image.new("RGBA", (w, h), shadow + (255,))
    sh.putalpha(full)
    out.alpha_composite(sh, (size // 40, size // 11))
    ol = Image.new("RGBA", (w, h), outline + (255,))
    ol.putalpha(full)
    out.alpha_composite(ol)
    il = Image.new("RGBA", (w, h), WHITE + (255,))
    il.putalpha(mask(inner))
    out.alpha_composite(il)
    grad = Image.new("RGB", (1, h))
    y0, y1 = pad + (b - t) * 0.05, h - pad
    for y in range(h):
        k = max(0.0, min(1.0, (y - y0) / max(1, y1 - y0)))
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)))
    fill = grad.resize((w, h)).convert("RGBA")
    fill.putalpha(mask(0))
    out.alpha_composite(fill)
    if tilt:
        out = out.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return out.crop(out.getbbox())


def equals(width, bar, gap, top, bottom, outline=INK):
    """A fat "=" in the glyph style (the font's own is tiny next to its capitals)."""
    pad = bar
    w, h = width + pad * 2, bar * 2 + gap + pad * 2

    def mask(grow):
        m = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(m)
        for y in (pad, pad + bar + gap):
            d.rounded_rectangle((pad - grow, y - grow, pad + width + grow, y + bar + grow), radius=bar // 3 + grow, fill=255)
        return m

    outer = max(6, bar // 3)
    out = Image.new("RGBA", (w + 20, h + 20), (0, 0, 0, 0))
    full = mask(outer)
    sh = Image.new("RGBA", (w, h), INK + (255,))
    sh.putalpha(full)
    out.alpha_composite(sh, (4, 14))
    ol = Image.new("RGBA", (w, h), outline + (255,))
    ol.putalpha(full)
    out.alpha_composite(ol, (0, 0))
    il = Image.new("RGBA", (w, h), WHITE + (255,))
    il.putalpha(mask(max(3, bar // 10)))
    out.alpha_composite(il, (0, 0))
    grad = Image.new("RGB", (1, h))
    for y in range(h):
        k = y / h
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)))
    fill = grad.resize((w, h)).convert("RGBA")
    fill.putalpha(mask(0))
    out.alpha_composite(fill, (0, 0))
    return out.crop(out.getbbox())


def hue(hh, s=0.9, v=1.0):
    return tuple(int(c * 255) for c in colorsys.hsv_to_rgb(hh % 1, s, v))


RAINBOW = [0.92, 0.0, 0.08, 0.14, 0.3, 0.55, 0.75]


def word(text, size, colors, tilt_seed=0, spacing=-0.06, bounce=True, outline=None):
    """Set a line letter by letter. colors(i) -> (top, bottom)."""
    tilts = [-5, 3, -2, 5, -4, 2, -3, 4]
    pieces = []
    k = 0
    for ch in text:
        if ch == " ":
            pieces.append((None, 0))
            continue
        top, bottom = colors(k)
        t = tilts[(k + tilt_seed) % len(tilts)] if bounce else 0
        dy = (8 if (k + tilt_seed) % 2 else -6) if bounce else 0
        pieces.append((glyph(ch, size, top, bottom, t, outline), dy))
        k += 1
    gap = int(size * spacing)
    space = int(size * 0.32)
    w = sum((p.width + gap) if p else space for p, _ in pieces) - gap
    h = max(p.height for p, _ in pieces if p) + 30
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for p, dy in pieces:
        if p is None:
            x += space
            continue
        out.alpha_composite(p, (x, max(0, min(h - p.height, h - p.height - 15 + dy))))
        x += p.width + gap
    return out


def rainbow_word(text, size, seed=0):
    return word(text, size, lambda i: (hue(RAINBOW[(i + seed) % len(RAINBOW)], 0.4, 1.0),
                                       hue(RAINBOW[(i + seed) % len(RAINBOW)], 0.95, 0.98)), seed)


def number(text, size, top, bottom, outline, bounce=False):
    return word(text, size, lambda i: (top, bottom), 0, spacing=-0.03, bounce=bounce, outline=outline)


GREEN = ((200, 255, 130), (58, 205, 40), (12, 84, 24))
GOLD = ((255, 246, 150), (255, 186, 20), (120, 64, 0))
PINK = ((255, 200, 235), (255, 60, 160), (110, 10, 70))


def rotate(im, deg):
    im = im.rotate(deg, resample=Image.BICUBIC, expand=True)
    return im.crop(im.getbbox())


def bangs(size=150, tilt=12):
    a = glyph("!", size, (255, 120, 110), (230, 20, 30), -8)
    b = glyph("!", int(size * 0.86), (255, 120, 110), (230, 20, 30), 10)
    out = Image.new("RGBA", (a.width + b.width, max(a.height, b.height) + 30), (0, 0, 0, 0))
    out.alpha_composite(a, (0, 0))
    out.alpha_composite(b, (a.width - 12, 26))
    return rotate(out, tilt)


def arrow(im, start, end, bend=0.35, width=46, color=(240, 30, 40)):
    """A fat curved arrow with an ink outline, from start to end (the head at end)."""
    sx, sy = start
    ex, ey = end
    mx, my = (sx + ex) / 2, (sy + ey) / 2
    cx, cy = mx - (ey - sy) * bend, my + (ex - sx) * bend
    pts = []
    N = 40
    for i in range(N + 1):
        t = i / N
        pts.append(((1 - t) ** 2 * sx + 2 * (1 - t) * t * cx + t * t * ex,
                    (1 - t) ** 2 * sy + 2 * (1 - t) * t * cy + t * t * ey))
    hx, hy = pts[-1]
    tx, ty = hx - pts[-6][0], hy - pts[-6][1]
    tl = math.hypot(tx, ty)
    tx, ty = tx / tl, ty / tl
    hs = width * 1.9
    base = (hx - tx * hs, hy - ty * hs)
    head = [(hx + tx * hs * 0.25, hy + ty * hs * 0.25),
            (base[0] - ty * hs * 0.75, base[1] + tx * hs * 0.75),
            (base[0] + ty * hs * 0.75, base[1] - tx * hs * 0.75)]
    body = [p for p in pts if math.hypot(p[0] - hx, p[1] - hy) > hs * 0.8]
    if len(body) < 2:
        return
    dense = []
    for (x0, y0), (x1, y1) in zip(body, body[1:]):
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / 3))
        dense += [(x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps) for k in range(steps)]
    dense.append(body[-1])

    def draw(d, extra, fill):
        r = (width + extra * 2) / 2
        for x, y in dense:
            d.ellipse((x - r, y - r, x + r, y + r), fill=fill)
        k = 1 + extra / hs * 2.2
        cxh, cyh = sum(p[0] for p in head) / 3, sum(p[1] for p in head) / 3
        d.polygon([(cxh + (p[0] - cxh) * k, cyh + (p[1] - cyh) * k) for p in head], fill=fill)

    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw(ImageDraw.Draw(sh), 12, INK + (255,))
    lay.alpha_composite(sh, (4, 10))
    d = ImageDraw.Draw(lay)
    draw(d, 12, INK + (255,))
    draw(d, 0, color + (255,))
    im.alpha_composite(lay)


def put(im, piece, x, y, anchor="tl"):
    """Paste a type piece by its top-left, top-centre ('tc') or centre ('c')."""
    if anchor == "tc":
        x -= piece.width // 2
    elif anchor == "c":
        x -= piece.width // 2
        y -= piece.height // 2
    im.alpha_composite(piece, (int(x), int(y)))
    return (int(x), int(y), int(x) + piece.width, int(y) + piece.height)


def at(t, x, y):
    """Capture pixel -> thumbnail pixel (t = the scale and crop top load() returned)."""
    s, left, top = t
    return (x - left) * s, (y - top) * s


def box(t, x0, y0, x1, y1):
    a, b = at(t, x0, y0), at(t, x1, y1)
    return (a[0], a[1], b[0], b[1])


def save(im, name, size=None):
    im = im.convert("RGB")
    if size:
        im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(DEST, name), optimize=True)
    print("marketing/" + name)


# ---------------------------------------------------------------- the shots

def thumb_bounce():
    """1: the avatar cheers by the slingshot; the goo bounces off a jelly pad up to a Mythic
    Prism Blob. BOUNCE = RARER."""
    src, mask, t = load("bounce", 60)
    im = punch(src).convert("RGBA")
    clean_fg = im.copy()  # the foreground is pasted back from before the glows and streaks
    blob = box(t, 1085, 145, 1390, 410)
    streaks(im)
    glow(im, blob, (255, 120, 220), 1.25, 230)
    rays(im, ((blob[0] + blob[2]) / 2, (blob[1] + blob[3]) / 2), (255, 236, 250), n=14, alpha=60)
    sticker(im, mask, src=clean_fg)
    sparkles(im, blob, (255, 170, 230), n=12, seed=3)
    tb = put(im, rainbow_word("BOUNCE", 190, 0), 50, 18)
    eq = put(im, equals(96, 30, 22, GOLD[0], GOLD[1], GOLD[2]), tb[0] + 30, tb[3] + 14)
    put(im, number("RARER!", 150, *GOLD), eq[2] + 10, tb[3] - 30)
    tag = rotate(number("MYTHIC", 92, *PINK, bounce=True), -6)
    put(im, tag, blob[2] - 40, blob[3] + 10, "tc")
    vignette(im, 0.25)
    save(im, "thumbnail_1_bounce.png")


def thumb_merge():
    """2: Normal -> Chonky -> Mega of the same squishy, the avatar cheering. MERGE TO MEGA, and
    the income each size earns (x1, x4, x16: Config.Squishies.SizeMult)."""
    src, mask, t = load("merge", 30, 1.06)
    im = punch(src).convert("RGBA")
    clean_fg = im.copy()
    normal, chonky, mega = box(t, 505, 525, 690, 718), box(t, 730, 460, 978, 716), box(t, 1018, 385, 1375, 712)
    streaks(im)
    glow(im, mega, (255, 225, 120), 1.1, 200)
    sticker(im, mask, src=clean_fg)
    sparkles(im, mega, (255, 230, 120), n=10, seed=5)
    for a, b in ((normal, chonky), (chonky, mega)):
        arrow(im, ((a[0] + a[2]) / 2 + 20, a[1] - 20), ((b[0] + b[2]) / 2 - 30, b[1] - 40), bend=-0.35, width=34, color=(255, 70, 170))
    for bx, txt, size in ((normal, "x1", 96), (chonky, "x4", 112), (mega, "x16", 140)):
        put(im, number(txt, size, *GOLD), (bx[0] + bx[2]) / 2, bx[3] - 10, "tc")
    t1 = rainbow_word("MERGE", 180, 1)
    t2 = number("TO MEGA!", 150, *GREEN)
    tb = put(im, t1, W // 2 - (t1.width + t2.width + 40) // 2, 10)
    put(im, t2, tb[2] + 40, tb[1] + 30)
    vignette(im, 0.25)
    save(im, "thumbnail_2_merge.png")


def thumb_collect():
    """3: the avatar with a crowd of rare squishies. 24 to collect (Config.Squishies.List)."""
    src, mask, t = load("collect", 70, 1.1)
    im = punch(src).convert("RGBA")
    clean_fg = im.copy()
    crowd = box(t, 0, 470, 1563, 800)
    streaks(im)
    rays(im, (W / 2, at(t, 780, 600)[1]), (255, 245, 220), n=18, alpha=55)
    sticker(im, mask, 10, clean_fg)
    sparkles(im, crowd, (255, 220, 140), n=18, seed=9, rmin=14, rmax=30)
    t1 = rainbow_word("COLLECT ALL", 160, 3)
    tb = put(im, t1, W // 2, 8, "tc")
    put(im, number("24 SQUISHIES", 140, *GREEN), W // 2, tb[3] - 34, "tc")
    vignette(im, 0.25)
    save(im, "thumbnail_3_collect.png")


def icon():
    """The Mega Mochi mid-squash on a lemon starburst, goo splats flying. No text."""
    src = Image.open(os.path.join(CAPS, "icon.jpg")).convert("RGB")
    msk = clean(Image.open(os.path.join(CAPS, "icon_mask.jpg")).convert("L"))
    bb = msk.getbbox()
    # a square crop round the squishy with a little room
    cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2 + 10
    half = max(bb[2] - bb[0], bb[3] - bb[1]) * 0.62
    crop = (int(cx - half), int(cy - half), int(cx + half), int(cy + half))
    S = 1024
    fg = punch(src.crop(crop).resize((S, S), Image.LANCZOS), 1.45, 1.1).convert("RGBA")
    m = msk.crop(crop).resize((S, S), Image.LANCZOS)
    im = Image.new("RGBA", (S, S), (255, 214, 40, 255))
    g = Image.new("L", (S, S), 0)  # lighter centre
    ImageDraw.Draw(g).ellipse((S * 0.1, S * 0.1, S * 0.9, S * 0.9), fill=255)
    g = g.filter(ImageFilter.GaussianBlur(S * 0.15))
    c = Image.new("RGBA", (S, S), (255, 246, 170, 255))
    c.putalpha(g)
    im.alpha_composite(c)
    rays(im, (S / 2, S * 0.55), (255, 255, 235), n=16, alpha=120, width_deg=11)
    for x, y, r, col, sd in ((150, 190, 70, (255, 79, 163), 1), (880, 230, 58, (255, 79, 163), 2),
                             (120, 820, 60, (155, 110, 255), 3), (900, 840, 74, (255, 79, 163), 4),
                             (520, 120, 34, (90, 200, 255), 5)):
        splat(im, x, y, r, col, sd)
    # the squishy, outlined
    glow(im, (S * 0.2, S * 0.2, S * 0.8, S * 0.8), (255, 255, 255), 1.0, 150)
    sticker(im, m, 14, fg)
    sparkles(im, (S * 0.18, S * 0.12, S * 0.82, S * 0.8), (255, 255, 255), n=8, seed=2, rmin=18, rmax=34)
    save(im, "icon.png", (512, 512))


if __name__ == "__main__":
    thumb_bounce()
    thumb_merge()
    thumb_collect()
    icon()
