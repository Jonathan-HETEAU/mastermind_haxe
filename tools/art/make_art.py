#!/usr/bin/env python3
"""
Generates the art of the game in a Victorian style: a walnut case, a Calacatta marble board
inlaid with gilt fillets, brass fittings and pions turned in fine stones.

    python3 tools/art/make_art.py        (needs Pillow and numpy)

Everything is procedural and seeded: running it again gives the same files. Writes into
res/Image (tiles and background), web (icons of the page) and res/fonts (bitmap fonts made from Playfair Display, see
tools/art/fonts/OFL.txt).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
IMG = os.path.join(ROOT, "res", "Image")
FONTS = os.path.join(ROOT, "res", "fonts")

# Layout of the scene, in virtual pixels: keep in sync with src/game/Game.hx.
SCENE_W, SCENE_H = 848, 1696
BOARD_X, BOARD_Y = 40, 112          # top left of the board (secret row) in the scene
CELL, RESULT = 128, 64
CODE_SIZE, TRIES = 4, 10
PALETTE_Y = BOARD_Y + (TRIES + 1) * CELL + 32
MARBLE = (BOARD_X + 48, BOARD_Y - 8, BOARD_X + 720, BOARD_Y + (TRIES + 1) * CELL + 12)

LIGHT = np.array([-0.45, -0.65, 0.62])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


# --- Noise and colors ---------------------------------------------------------------------

def noise(rng, h, w, sy, sx=None):
    """Smooth noise in [0, 1] with features about sy (vertically) by sx (horizontally) pixels."""
    sx = sy if sx is None else sx
    gh, gw = max(2, int(h / sy) + 3), max(2, int(w / sx) + 3)
    grid = rng.random((gh, gw)).astype(np.float32)
    return np.asarray(Image.fromarray(grid, "F").resize((w, h), Image.BICUBIC))


def fbm(rng, h, w, sy, sx=None, octaves=5):
    sx = sy if sx is None else sx
    total, amp, norm = np.zeros((h, w), np.float32), 1.0, 0.0
    for i in range(octaves):
        total += amp * noise(rng, h, w, max(1, sy / 2 ** i), max(1, sx / 2 ** i))
        norm += amp
        amp *= 0.5
    return total / norm


def ramp(t, stops):
    """Maps t in [0, 1] through color stops [(position, (r, g, b)), ...]: float RGB in [0, 1]."""
    pos = [p for p, _ in stops]
    t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, pos, [c[i] / 255 for _, c in stops]) for i in range(3)], -1)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def shade(height, strength=1.0):
    """Lighting of a height map (pixels): 1 on flat parts, more facing the light, less away."""
    gy, gx = np.gradient(height.astype(np.float32))
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n @ LIGHT) / LIGHT[2]


def box_blur(a, r, axis):
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)


def blur(a, radius):
    """About a Gaussian blur: three box blurs in each direction."""
    a = a.astype(np.float32)
    r = max(1, int(round(radius * 0.8)))
    for _ in range(3):
        a = box_blur(box_blur(a, r, 0), r, 1)
    return a


def mask(size, draw_fn, ss=4):
    """A float mask in [0, 1] drawn with PIL at ss times the size, then reduced (antialiasing)."""
    w, h = size
    im = Image.new("L", (w * ss, h * ss), 0)
    draw_fn(ImageDraw.Draw(im), ss)
    return np.asarray(im.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def rgba(rgb, alpha):
    a = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    return Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA")


def save(im, name):
    path = os.path.join(IMG, name)
    if name.endswith(".jpg"):
        im.convert("RGB").save(path, quality=90, optimize=True)
    else:
        im.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


# --- Materials ----------------------------------------------------------------------------

def walnut(rng, h, w, vertical=True, tone=1.0):
    """Polished walnut: rings warped by noise, fine fibers and pores, under varnish."""
    if not vertical:
        return np.transpose(walnut(rng, w, h, True, tone), (1, 0, 2))
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = fbm(rng, h, w, 500, 90, 4)
    v = x / 46 + warp * 9 + fbm(rng, h, w, 120, 30, 3) * 1.5
    rings = 0.5 + 0.5 * np.sin(v * 2 * np.pi)
    rings = rings ** 1.6
    fibers = noise(rng, h, w, 90, 1.6)
    pores = smoothstep(0.72, 0.9, noise(rng, h, w, 7, 1.2))
    figure = fbm(rng, h, w, 260, 260, 3)
    t = 0.45 * rings + 0.25 * fibers + 0.3 * figure - 0.18 * pores
    col = ramp(t, [(0.0, (38, 20, 11)), (0.35, (66, 37, 20)), (0.65, (102, 60, 31)), (1.0, (138, 86, 45))])
    return col * tone


def marble(rng, h, w):
    """Calacatta: warm white with soft clouds, long grey veins and a few gilded ones."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    clouds = fbm(rng, h, w, 300, 300, 5)
    base = ramp(clouds, [(0, (224, 219, 209)), (0.5, (240, 236, 228)), (1, (250, 248, 243))])

    def veins(direction, period, turbulence, width):
        # A dominant direction bent by large noise, roughened by fine noise: no closed loops.
        t = fbm(rng, h, w, 420, 420, 3) * turbulence + fbm(rng, h, w, 40, 40, 4) * 0.1
        v = (x * direction[0] + y * direction[1]) / period + t
        d = np.abs(np.sin(np.pi * v))
        wmod = width * (0.3 + 1.4 * noise(rng, h, w, 220))
        line = 1 - smoothstep(0, 1, d / wmod)
        # Veins fade in and out along their length.
        return line * smoothstep(0.25, 0.65, noise(rng, h, w, 260))

    big = veins((0.45, 1.0), 400, 1.7, 0.07)
    fine = veins((1.0, -0.5), 150, 1.3, 0.025) * 0.4
    capillary = veins((0.2, 1.0), 70, 1.0, 0.012) * 0.18
    gold_sel = smoothstep(0.55, 0.75, noise(rng, h, w, 400))
    grey = np.array([0.40, 0.39, 0.38])
    gold = np.array([0.69, 0.55, 0.30])
    vein_col = grey * (1 - gold_sel[..., None]) + gold * gold_sel[..., None]
    a = np.clip(big * 0.6 + fine + capillary, 0, 1)[..., None]
    halo = blur(np.clip(big, 0, 1), 16)[..., None] * 0.3 * (0.5 + noise(rng, h, w, 120))[..., None]
    return base * (1 - a - halo) + vein_col * a + vein_col * halo


def brass(rng, h, w, brushed=True):
    t = noise(rng, h, w, 1.2 if brushed else 40, 140 if brushed else 40) * 0.5 + fbm(rng, h, w, 60, 60, 3) * 0.5
    return ramp(t, [(0, (128, 92, 38)), (0.45, (186, 146, 68)), (0.75, (214, 178, 96)), (1, (236, 208, 140))])


def velvet(rng, h, w):
    t = noise(rng, h, w, 1.5) * 0.35 + fbm(rng, h, w, 80, 80, 4) * 0.65
    return ramp(t, [(0, (52, 8, 14)), (0.5, (86, 16, 24)), (1, (118, 28, 36))])


def gilt(height_mask, rng, strength=2.5):
    """Gold leaf over a relief: color from the lighting of the height map."""
    h, w = height_mask.shape
    light = shade(height_mask * 6, strength)
    col = brass(rng, h, w, brushed=False)
    hi = np.clip(light - 1, 0, 1)[..., None]
    return col * np.clip(light, 0.25, 1.6)[..., None] + hi * 0.25


# --- Background ---------------------------------------------------------------------------

def rect_bevel(h, w, box, width):
    """A height map rising from 0 at the edge of box to 1 at `width` pixels inside."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    x0, y0, x1, y1 = box
    d = np.minimum.reduce([x - x0, x1 - x, y - y0, y1 - y])
    return np.clip(d / width, 0, 1) * (d >= 0)


def inside(h, w, box):
    y, x = np.mgrid[0:h, 0:w]
    x0, y0, x1, y1 = box
    return ((x >= x0) & (x < x1) & (y >= y0) & (y < y1)).astype(np.float32)


def background(rng):
    h, w = SCENE_H, SCENE_W
    col = walnut(rng, h, w)

    # The case: a raised moulding around, then the flat panel.
    frame = rect_bevel(h, w, (0, 0, w, h), 18) - 0.6 * rect_bevel(h, w, (26, 26, w - 26, h - 26), 6)
    col *= np.clip(shade(frame * 10, 1.0), 0.35, 1.5)[..., None]

    # The marble inlay, sunk a little, inside a gilt fillet.
    mx0, my0, mx1, my1 = MARBLE
    fillet = inside(h, w, (mx0 - 8, my0 - 8, mx1 + 8, my1 + 8)) - inside(h, w, MARBLE)
    fillet_h = blur(fillet, 1.5)
    col = col * (1 - fillet[..., None]) + gilt(fillet_h, rng) * fillet[..., None]
    m = inside(h, w, MARBLE)
    stone = marble(rng, h, w)
    inner_shadow = 1 - 0.28 * (1 - rect_bevel(h, w, MARBLE, 14)) ** 2
    stone *= inner_shadow[..., None]
    col = col * (1 - m[..., None]) + stone * m[..., None]

    # A gilt line under the secret row, and one between the code and the results.
    line_y = BOARD_Y + CELL
    line = inside(h, w, (mx0, line_y - 3, mx1, line_y + 3))
    col = col * (1 - line[..., None]) + gilt(blur(line, 1), rng) * line[..., None]
    lx = BOARD_X + RESULT + CODE_SIZE * CELL
    vline = inside(h, w, (lx - 2, line_y + 3, lx + 2, my1))
    col = col * (1 - vline[..., None]) + gilt(blur(vline, 1), rng) * vline[..., None]

    # The velvet tray of the palette, sunk in the wood.
    tray = (BOARD_X - 12, PALETTE_Y - 10, BOARD_X + 6 * CELL + 12, PALETTE_Y + CELL + 6)
    t = inside(h, w, tray)
    vel = velvet(rng, h, w) * (1 - 0.5 * (1 - rect_bevel(h, w, tray, 16)) ** 2)[..., None]
    tray_lip = rect_bevel(h, w, (tray[0] - 8, tray[1] - 8, tray[2] + 8, tray[3] + 8), 8) * (1 - t)
    col *= np.clip(shade(-tray_lip * 6, 1.0), 0.4, 1.4)[..., None]
    col = col * (1 - t[..., None]) + vel * t[..., None]

    # The brass name plate.
    plate = (w // 2 - 250, 26, w // 2 + 250, 92)
    pm = mask((w, h), lambda d, s: d.rounded_rectangle([c * s for c in plate], radius=14 * s, fill=255))
    plate_h = blur(pm, 3)
    pcol = brass(rng, h, w) * np.clip(shade(plate_h * 8, 1.4), 0.4, 1.5)[..., None]
    shadow = blur(pm, 6)
    shadow = np.roll(np.roll(shadow, 5, 0), 4, 1)
    col *= (1 - 0.5 * shadow * (1 - pm))[..., None]
    col = col * (1 - pm[..., None]) + pcol * pm[..., None]
    engrave(col, "MASTERMIND", os.path.join(HERE, "fonts", "PlayfairDisplaySC-Bold.ttf"), 50,
            (w // 2, (plate[1] + plate[3]) // 2 + 1))
    for sx in (plate[0] + 22, plate[2] - 22):
        screw(col, rng, sx, (plate[1] + plate[3]) // 2, 7)

    # Brass corner pieces on the case.
    for cx, cy in ((44, 44), (w - 44, 44)):
        rosette(col, rng, cx, cy, 16)

    # Varnish: a broad soft sheen, and a vignette.
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    sheen = np.exp(-(((x - w * 0.3) / (w * 0.5)) ** 2 + ((y - h * 0.25) / (h * 0.45)) ** 2))
    col = col * (0.92 + 0.14 * sheen[..., None])
    vign = 1 - 0.28 * (((x / w - 0.5) * 2) ** 2 + ((y / h - 0.5) * 2) ** 2) ** 1.5
    col *= np.clip(vign, 0.55, 1)[..., None]
    save(rgba(col, np.ones((h, w))), "background.jpg")


def engrave(col, text, font_path, size, center):
    """Text cut into the metal: a dark groove with a light lower edge."""
    h, w = col.shape[:2]
    font = ImageFont.truetype(font_path, size * 4)
    m = mask((w, h), lambda d, s: d.text((center[0] * s, center[1] * s), text, font=font, fill=255, anchor="mm"))
    lower = np.roll(np.roll(m, 1, 0), 1, 1) * (1 - m)
    col *= (1 - 0.72 * m)[..., None]
    col += (lower * 0.22)[..., None]


def screw(col, rng, cx, cy, r):
    h, w = col.shape[:2]
    m = mask((w, h), lambda d, s: d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=255))
    slot = mask((w, h), lambda d, s: d.line([(cx - r + 2) * s, (cy - r + 3) * s, (cx + r - 2) * s, (cy + r - 3) * s], fill=255, width=2 * s))
    dome = blur(m, 2)
    c = brass(rng, h, w, False) * np.clip(shade(dome * 5, 1.2), 0.3, 1.6)[..., None]
    c *= (1 - 0.7 * slot)[..., None]
    col[:] = col * (1 - m[..., None]) + c * m[..., None]


def rosette(col, rng, cx, cy, r):
    h, w = col.shape[:2]

    def draw(d, s):
        pts = []
        for i in range(16):
            a = i * np.pi / 8
            rr = r if i % 2 == 0 else r * 0.55
            pts.append(((cx + rr * np.cos(a)) * s, (cy + rr * np.sin(a)) * s))
        d.polygon(pts, fill=255)
    m = mask((w, h), draw)
    c = gilt(blur(m, 1.5), rng, 3)
    col[:] = col * (1 - m[..., None]) + c * m[..., None]
    screw(col, rng, cx, cy, int(r * 0.35))


# --- Tiles --------------------------------------------------------------------------------

def hole(rng, size, r_cup, ring):
    """A cup cut in the marble with a brass ring: drawn over the background."""
    n = size * 4
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = n / 2
    d = np.hypot(x - c, y - c) / 4
    cup = d < r_cup
    ring_m = (d >= r_cup) & (d < r_cup + ring)
    # Inside: the rim casts a crescent of shadow on the side of the light (top left), the far
    # wall catches the light.
    nx, ny = (x - c) / 4 / r_cup, (y - c) / 4 / r_cup
    l2 = LIGHT[:2] / np.linalg.norm(LIGHT[:2])
    shadow = smoothstep(0.92, 1.04, np.hypot(nx + 0.42 * l2[0], ny + 0.42 * l2[1]))
    lit = np.clip(-(nx * l2[0] + ny * l2[1]), 0, 1) * smoothstep(0.5, 1.0, np.hypot(nx, ny))
    alpha = np.where(cup, 0.22 + 0.5 * shadow + 0.12 * np.hypot(nx, ny) ** 2 - 0.12 * lit, 0)
    rgb = np.zeros((n, n, 3), np.float32) + np.array([0.08, 0.06, 0.05])
    # The ring: a rounded brass profile.
    t = np.clip((d - r_cup) / ring, 0, 1)
    profile = np.sin(t * np.pi)
    ring_light = 0.55 + 0.75 * np.clip(-((x - c) * LIGHT[0] + (y - c) * LIGHT[1]) / (4 * (r_cup + ring)) * (1 - 2 * t) + profile * 0.4, -0.4, 1)
    b = brass(rng, n, n, False)
    rgb = np.where(ring_m[..., None], b * ring_light[..., None], rgb)
    alpha = np.where(ring_m, 1.0, alpha)
    # A soft shadow of the ring on the marble.
    sh = blur(((d < r_cup + ring)).astype(np.float32), 6)
    sh = np.roll(np.roll(sh, 6, 0), 5, 1) * (d >= r_cup + ring)
    alpha = np.maximum(alpha, sh * 0.35)
    im = rgba(rgb, alpha)
    return im.resize((size, size), Image.LANCZOS)


def stone(kind, rng, n):
    """A texture of size n in [0, 1] RGB, and its translucency and gloss."""
    u = fbm(rng, n, n, n / 3, n / 3, 5)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    if kind == "onyx":
        bands = 0.5 + 0.5 * np.sin((y * 9 + u * 3) * 2 * np.pi)
        return ramp(bands * 0.6 + u * 0.4, [(0, (10, 9, 9)), (0.7, (24, 22, 22)), (1, (52, 48, 46))]), 0, 1.0
    if kind == "ivory":
        grain = 0.5 + 0.5 * np.sin((x * 40 + u * 6) * 2 * np.pi)
        return ramp(grain * 0.25 + u * 0.75, [(0, (206, 192, 160)), (0.5, (232, 222, 196)), (1, (248, 242, 224))]), 0.15, 0.7
    if kind == "amber":
        inc = smoothstep(0.8, 0.95, noise(rng, n, n, n / 30))
        return ramp(u - inc * 0.3, [(0, (120, 52, 6)), (0.5, (196, 112, 18)), (1, (246, 178, 52))]), 0.8, 1.0
    if kind == "lapis":
        c = ramp(u, [(0, (14, 24, 92)), (0.5, (28, 50, 150)), (1, (58, 86, 186))])
        calcite = smoothstep(0.82, 0.95, fbm(rng, n, n, n / 6, n / 6, 4))[..., None]
        c = c * (1 - calcite * 0.5) + np.array([0.75, 0.78, 0.85]) * calcite * 0.5
        flecks = (rng.random((n, n)) > 0.9965).astype(np.float32)
        flecks = np.clip(blur(flecks, 1.2) * 6, 0, 1)[..., None]
        return c * (1 - flecks) + np.array([0.92, 0.76, 0.36]) * flecks, 0, 1.0
    if kind == "ruby":
        return ramp(u * 0.7 + 0.3 * np.hypot(x - 0.5, y - 0.5) * 2, [(0, (60, 2, 12)), (0.5, (128, 10, 26)), (1, (200, 34, 48))]), 0.9, 1.0
    if kind == "malachite":
        d = np.hypot(x - 0.25, y - 0.7) * 16 + u * 3
        bands = 0.5 + 0.5 * np.sin(d * 2 * np.pi)
        bands = bands ** 0.7
        return ramp(bands, [(0, (4, 52, 34)), (0.5, (16, 112, 72)), (1, (52, 172, 112))]), 0, 1.0
    if kind == "gold":
        return ramp(u, [(0, (150, 108, 36)), (0.6, (212, 168, 72)), (1, (240, 206, 120))]), 0, 1.0
    if kind == "silver":
        return ramp(u, [(0, (150, 150, 158)), (0.6, (206, 206, 214)), (1, (240, 240, 246))]), 0, 1.0
    raise ValueError(kind)


def sphere(kind, rng, size, radius, metal=False):
    """A polished stone ball lit from the top left, with its shadow."""
    ss = 4
    n = size * ss
    tex, translucency, gloss = stone(kind, rng, 512)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = n / 2 - ss * 2
    R = radius * ss
    nx, ny = (x - c) / R, (y - c) / R
    r2 = nx * nx + ny * ny
    inside_m = r2 <= 1
    nz = np.sqrt(np.clip(1 - r2, 0, 1))
    # Spherical texture coordinates, so the pattern wraps around the ball.
    u = np.arctan2(nx, nz + 1e-6) / np.pi * 0.5 + 0.5
    v = np.arcsin(np.clip(ny, -1, 1)) / np.pi + 0.5
    albedo = tex[np.clip((v * 511).astype(int), 0, 511), np.clip((u * 511).astype(int), 0, 511)]
    nrm = np.stack([nx, ny, nz], -1)
    diff = np.clip(nrm @ LIGHT, 0, 1)
    half = LIGHT + np.array([0, 0, 1.0])
    half /= np.linalg.norm(half)
    spec = np.clip(nrm @ half, 0, 1)
    fres = (1 - nz) ** 3
    if metal:
        col = albedo * (0.25 + 1.0 * diff[..., None]) + albedo * (spec ** 30)[..., None] * 1.2 + (spec ** 200)[..., None] * 0.8
    else:
        col = albedo * (0.22 + 0.9 * diff[..., None])
        # Light going through the stone gathers on the side away from the light.
        glow = np.exp(-((nx - 0.32) ** 2 + (ny - 0.42) ** 2) / 0.12)
        col += albedo * 1.1 * translucency * glow[..., None]
        col += (spec ** 120)[..., None] * 1.1 * gloss + (spec ** 12)[..., None] * 0.12 * gloss
        # The reflection of a window, and of the room on the rim.
        win = smoothstep(0.08, 0.0, np.abs(nx + 0.36) - 0.12) * smoothstep(0.1, 0.0, np.abs(ny + 0.42) - 0.1)
        col += win[..., None] * 0.35 * gloss
        col += fres[..., None] * np.array([0.30, 0.24, 0.18]) * 0.5 * gloss
    alpha = inside_m.astype(np.float32)
    # The shadow on the board, offset away from the light.
    sh = np.exp(-(((x - c - 0.18 * R) / (R * 1.0)) ** 2 + ((y - c - 0.24 * R) / (R * 0.95)) ** 2) * 2.2) * 0.6
    rgb = np.where(inside_m[..., None], col, 0)
    out_alpha = np.where(inside_m, 1.0, sh)
    im = rgba(rgb, out_alpha)
    return im.resize((size, size), Image.LANCZOS)


def medallion(rng, size, radius, symbol):
    """A brass push button with an engraved symbol."""
    n = size * 4
    c = n / 2
    R = radius * 4
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.hypot(x - c, y - c)
    disc = (d <= R).astype(np.float32)
    dome = np.clip(1 - (d / R) ** 2, 0, 1) ** 0.5 * 30 + np.where(d > R * 0.82, -(d - R * 0.82) * 0.6, 0)
    light = np.clip(shade(dome, 0.35), 0.35, 1.6)
    col = brass(rng, n, n, False) * light[..., None]
    rim = (d > R * 0.8) & (d < R * 0.86)
    col *= np.where(rim, 0.65, 1.0)[..., None]
    sym = Image.new("L", (n, n), 0)
    dr = ImageDraw.Draw(sym)
    s = R / 50
    if symbol == "check":
        dr.line([(c - 22 * s, c + 2 * s), (c - 6 * s, c + 18 * s), (c + 24 * s, c - 18 * s)], fill=255, width=int(9 * s), joint="curve")
    else:
        r = 21 * s
        dr.arc([c - r, c - r, c + r, c + r], -15, 255, fill=255, width=int(8 * s))
        a = np.radians(255)
        end = np.array([c + r * np.cos(a), c + r * np.sin(a)])
        tangent = np.array([-np.sin(a), np.cos(a)])      # clockwise, in screen coordinates
        normal = np.array([np.cos(a), np.sin(a)])
        tip = end + tangent * 15 * s
        base = end - tangent * 3 * s
        dr.polygon([tuple(tip), tuple(base + normal * 13 * s), tuple(base - normal * 13 * s)], fill=255)
    m = np.asarray(sym).astype(np.float32) / 255
    lower = np.roll(np.roll(m, 4, 0), 3, 1) * (1 - m)
    col = col * (1 - 0.75 * m)[..., None] + (lower * 0.3)[..., None]
    sh = np.roll(np.roll(blur(disc, 10), 14, 0), 10, 1) * 0.5
    alpha = np.maximum(disc, sh * (1 - disc))
    col = np.where(disc[..., None] > 0, col, 0)
    return rgba(col, alpha).resize((size, size), Image.LANCZOS)


def gilt_frame(rng, size, inset, width):
    """A gilded frame with diamonds at the corners: the selection and the cursor."""
    def draw(d, s):
        a, b = inset * s, (size - inset) * s
        d.rounded_rectangle([a, a, b, b], radius=10 * s, outline=255, width=width * s)
        for cx, cy in ((a, a), (b, a), (a, b), (b, b)):
            r = (width + 6) * s
            d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=255)
    m = mask((size, size), draw)
    col = gilt(blur(m, 1.2), rng, 3)
    sh = np.roll(np.roll(blur(m, 3), 3, 0), 2, 1) * 0.5
    alpha = np.maximum(m, sh * (1 - m))
    return rgba(np.where(m[..., None] > 0, col, 0), alpha)


def lid(rng, w, h, pad):
    """The walnut shutter that hides the secret code, with a brass keyhole."""
    W, H = w + 2 * pad, h + 2 * pad
    m = mask((W, H), lambda d, s: d.rounded_rectangle([pad * s, pad * s, (W - pad) * s, (H - pad) * s], radius=12 * s, fill=255))
    col = walnut(rng, H, W, vertical=False, tone=1.05)
    bevel = rect_bevel(H, W, (pad, pad, W - pad, H - pad), 10)
    panel = rect_bevel(H, W, (pad + 22, pad + 18, W - pad - 22, H - pad - 18), 6)
    col *= np.clip(shade(bevel * 8 + panel * 4, 1.0), 0.35, 1.6)[..., None]
    # Brass hinges at both ends.
    for hx in (pad + 4, W - pad - 30):
        hm = inside(H, W, (hx, pad + 30, hx + 26, H - pad - 30))
        hc = brass(rng, H, W) * np.clip(shade(blur(hm, 2) * 5, 1.0), 0.4, 1.5)[..., None]
        col = col * (1 - hm[..., None]) + hc * hm[..., None]
        for sy in (pad + 42, H - pad - 42):
            screw(col, rng, hx + 13, sy, 5)
    # The escutcheon and its keyhole.
    cx, cy = W // 2, H // 2

    def esc(d, s):
        d.ellipse([(cx - 26) * s, (cy - 30) * s, (cx + 26) * s, (cy + 30) * s], fill=255)
    em = mask((W, H), esc)
    ec = gilt(blur(em, 2.5), rng, 2.2)
    col = col * (1 - em[..., None]) + ec * em[..., None]

    def key(d, s):
        d.ellipse([(cx - 7) * s, (cy - 15) * s, (cx + 7) * s, (cy - 1) * s], fill=255)
        d.polygon([(cx - 4) * s, (cy - 6) * s, (cx + 4) * s, (cy - 6) * s, (cx + 7) * s, (cy + 16) * s, (cx - 7) * s, (cy + 16) * s], fill=255)
    km = mask((W, H), key)
    col *= (1 - 0.88 * km)[..., None]
    sh = np.roll(np.roll(blur(m, 5), 6, 0), 4, 1) * 0.55
    alpha = np.maximum(m, sh * (1 - m))
    return rgba(np.where(m[..., None] > 0, col, 0), alpha)


def panel(rng, w, h):
    """The end of game cartouche: walnut inside a double gilt fillet, rosettes at the corners."""
    col = walnut(rng, h, w, vertical=False, tone=0.8)
    outer = inside(h, w, (0, 0, w, h)) - inside(h, w, (10, 10, w - 10, h - 10))
    inner = inside(h, w, (20, 20, w - 20, h - 20)) - inside(h, w, (24, 24, w - 24, h - 24))
    for f in (outer, inner):
        col = col * (1 - f[..., None]) + gilt(blur(f, 1.2), rng) * f[..., None]
    col *= (1 - 0.35 * (1 - rect_bevel(h, w, (10, 10, w - 10, h - 10), 30)) ** 2)[..., None]
    for cx, cy in ((22, 22), (w - 22, 22), (22, h - 22), (w - 22, h - 22)):
        rosette(col, rng, cx, cy, 14)
    return rgba(col, np.ones((h, w)) * 0.96)


def icon(rng, size):
    """The icon of the page, for the home screen: four stones on marble in a walnut frame."""
    n = 512
    col = walnut(rng, n, n)
    m = inside(n, n, (40, 40, n - 40, n - 40))
    fillet = inside(n, n, (32, 32, n - 32, n - 32)) - m
    col = col * (1 - fillet[..., None]) + gilt(blur(fillet, 1.5), rng) * fillet[..., None]
    col = col * (1 - m[..., None]) + marble(rng, n, n) * (m * (1 - 0.25 * (1 - rect_bevel(n, n, (40, 40, n - 40, n - 40), 16)) ** 2))[..., None]
    im = rgba(col, np.ones((n, n)))
    for i, kind in enumerate(("ruby", "lapis", "malachite", "amber")):
        ball = sphere(kind, rng, 200, 72)
        im.alpha_composite(ball, (56 + (i % 2) * 200, 56 + (i // 2) * 200))
    return im.resize((size, size), Image.LANCZOS)


# --- Bitmap fonts -------------------------------------------------------------------------

CHARS = [chr(c) for c in range(32, 127)] + list("àâäçéèêëîïôöùûüÿœæÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸŒÆ«»’…€°")


def bitmap_font(name, path, size, weight):
    """A BMFont (text format) that Heaps reads with hxd.Res.fonts.<name>.toFont(): white glyphs, tinted by textColor."""
    font = ImageFont.truetype(path, size)
    try:
        font.set_variation_by_name(weight)
    except Exception:
        pass
    ascent, descent = font.getmetrics()
    pad = 2
    glyphs = []
    for ch in CHARS:
        l, t, r, b = font.getbbox(ch, anchor="ls")
        glyphs.append((ch, l, t, r, b, font.getlength(ch)))
    atlas_w = 1024
    x = y = pad
    row_h = 0
    placed = []
    for ch, l, t, r, b, adv in glyphs:
        gw, gh = max(1, r - l), max(1, b - t)
        if x + gw + pad > atlas_w:
            x, y = pad, y + row_h + pad
            row_h = 0
        placed.append((ch, x, y, gw, gh, l, t, adv))
        x += gw + pad
        row_h = max(row_h, gh)
    atlas_h = 1
    while atlas_h < y + row_h + pad:
        atlas_h *= 2
    alpha = Image.new("L", (atlas_w, atlas_h), 0)
    d = ImageDraw.Draw(alpha)
    lines = []
    for ch, gx, gy, gw, gh, l, t, adv in placed:
        if ch != " ":
            d.text((gx - l, gy - t), ch, font=font, fill=255, anchor="ls")
        lines.append(f"char id={ord(ch)} x={gx} y={gy} width={gw} height={gh} xoffset={l} yoffset={ascent + t} xadvance={round(adv)} page=0 chnl=15")
    white = Image.new("L", (atlas_w, atlas_h), 255)
    Image.merge("RGBA", (white, white, white, alpha)).save(os.path.join(FONTS, name + ".png"), optimize=True)
    with open(os.path.join(FONTS, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write(f'info face="Playfair Display" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing={pad},{pad}\n')
        f.write(f"common lineHeight={ascent + descent} base={ascent} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0\n")
        f.write(f'page id=0 file="{name}.png"\n')
        f.write(f"chars count={len(lines)}\n")
        f.write("\n".join(lines) + "\n")
    print("wrote", os.path.relpath(os.path.join(FONTS, name + ".fnt"), ROOT))


def main():
    os.makedirs(IMG, exist_ok=True)
    os.makedirs(FONTS, exist_ok=True)
    rng = np.random.default_rng(1851)
    background(rng)
    save(hole(rng, CELL, 40, 7), "cell.png")
    save(hole(rng, RESULT, 15, 4), "cell_mini.png")
    for kind, name in (("onyx", "noir"), ("ivory", "blanc"), ("amber", "jaune"), ("lapis", "bleu"), ("ruby", "rouge"), ("malachite", "vert")):
        save(sphere(kind, rng, CELL, 44), f"pion_{name}.png")
    save(sphere("gold", rng, RESULT, 17, metal=True), "good.png")
    save(sphere("silver", rng, RESULT, 17, metal=True), "bad.png")
    save(medallion(rng, CELL, 46, "check"), "validate.png")
    save(medallion(rng, CELL, 46, "restart"), "restart.png")
    save(gilt_frame(rng, CELL, 8, 5), "selection.png")
    save(lid(rng, CODE_SIZE * CELL, CELL, 12), "lid.png")
    save(panel(rng, 704, 400), "panel.png")
    web = os.path.join(ROOT, "web")
    for size in (192, 512):
        icon(np.random.default_rng(1851), size).convert("RGB").save(os.path.join(web, f"icon-{size}.png"), optimize=True)
        print("wrote", f"web/icon-{size}.png")
    playfair = os.path.join(HERE, "fonts", "PlayfairDisplay.ttf")
    bitmap_font("title", os.path.join(HERE, "fonts", "PlayfairDisplaySC-Bold.ttf"), 104, "Bold")
    bitmap_font("text", playfair, 46, "Regular")
    bitmap_font("small", playfair, 30, "Regular")


if __name__ == "__main__":
    main()
