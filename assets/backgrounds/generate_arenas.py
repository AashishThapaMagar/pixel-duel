"""
Generates the three additional Pixel Duel arena backdrops (960x540 PNGs) that
sit behind the existing Ground/StaticBody2D in Arena.tscn, matching the layered
look of generate_arena_bg.py (sky gradient + silhouette band + ground strip)
but re-themed per fighting style so the arena picker has real variety:

  arena_bg_dojo.png     Karate dojo courtyard: pagoda roofline, paper lanterns.
  arena_bg_stadium.png  Muay Thai stadium: floodlights, bleachers, ring ropes.
  arena_bg_neon.png     Freestyle MMA rooftop: neon skyline at night.

One-time art generation script — re-run after editing below.
"""
from PIL import Image, ImageDraw
import os
import random

W, H = 960, 540
HORIZON_Y = 420
OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky_gradient(d, top, mid, horizon, mid_stop=0.6):
    for y in range(HORIZON_Y):
        t = y / HORIZON_Y
        if t < mid_stop:
            color = lerp(top, mid, t / mid_stop)
        else:
            color = lerp(mid, horizon, (t - mid_stop) / (1 - mid_stop))
        d.line([(0, y), (W, y)], fill=color)
    d.rectangle([0, HORIZON_Y, W, H], fill=horizon)


def ground_strip(d, horizon_color, shade):
    for y in range(HORIZON_Y, H):
        t = (y - HORIZON_Y) / (H - HORIZON_Y)
        color = lerp(horizon_color, shade, t)
        d.line([(0, y), (W, y)], fill=color)


def stars(d, seed, count, max_y):
    rng = random.Random(seed)
    for _ in range(count):
        x = rng.randint(0, W - 1)
        y = rng.randint(0, max_y)
        b = rng.randint(150, 255)
        d.point((x, y), fill=(b, b, b))


def make_dojo():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    sky_gradient(d, (36, 20, 26), (110, 55, 50), (240, 150, 95), 0.55)

    # Distant temple ridge — soft rolling hill behind the pagodas.
    hill = [(0, HORIZON_Y)]
    rng = random.Random(21)
    x = 0
    while x < W:
        x += rng.randint(90, 150)
        hill.append((min(x, W), HORIZON_Y - rng.randint(20, 55)))
    hill.append((W, HORIZON_Y))
    d.polygon(hill, fill=(58, 34, 34))

    # Pagoda silhouettes: stacked tiered roofs (wide-narrow-narrower).
    rng2 = random.Random(5)
    x = -20
    PAGODA = (40, 22, 24)
    LANTERN = (255, 176, 90)
    while x < W + 20:
        base_w = rng2.randint(90, 140)
        tiers = rng2.randint(2, 3)
        tier_h = rng2.randint(26, 34)
        top_y = HORIZON_Y - tiers * tier_h - 30
        cx = x + base_w / 2
        # Trunk/body below the roof tiers.
        d.rectangle([cx - 14, top_y + tiers * tier_h, cx + 14, HORIZON_Y + 2], fill=PAGODA)
        for tier in range(tiers):
            w = base_w * (1.0 - tier * 0.22)
            ty = top_y + tier * tier_h
            d.polygon([(cx - w / 2, ty + tier_h), (cx, ty), (cx + w / 2, ty + tier_h)], fill=PAGODA)
            # Upturned eave tips.
            d.ellipse([cx - w / 2 - 6, ty + tier_h - 5, cx - w / 2 + 6, ty + tier_h + 5], fill=PAGODA)
            d.ellipse([cx + w / 2 - 6, ty + tier_h - 5, cx + w / 2 + 6, ty + tier_h + 5], fill=PAGODA)
        # Hanging paper lantern.
        if rng2.random() < 0.7:
            ly = HORIZON_Y - rng2.randint(10, 40)
            d.ellipse([cx - 5, ly - 7, cx + 5, ly + 7], fill=LANTERN)
        x += base_w + rng2.randint(30, 70)

    # Foreground wooden pillars framing the courtyard.
    for px in (60, 900):
        d.rectangle([px - 10, HORIZON_Y - 150, px + 10, HORIZON_Y + 4], fill=(30, 16, 18))
        d.ellipse([px - 5, HORIZON_Y - 168, px + 5, HORIZON_Y - 152], fill=LANTERN)

    ground_strip(d, (240, 150, 95), (48, 30, 26))
    img.save(os.path.join(OUT_DIR, "arena_bg_dojo.png"))


def make_stadium():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    sky_gradient(d, (10, 16, 26), (18, 30, 42), (60, 70, 60), 0.65)
    stars(d, 4, 25, int(HORIZON_Y * 0.35))

    # Bleacher silhouette: stepped stands packed with tiny spectator dots.
    STAND = (16, 22, 30)
    steps = 9
    step_w = W / steps
    rng = random.Random(9)
    for i in range(steps):
        step_h = 46 + (i % 3) * 16
        x0 = i * step_w
        y0 = HORIZON_Y - step_h
        d.rectangle([x0, y0, x0 + step_w + 1, HORIZON_Y + 2], fill=STAND)
        for _ in range(22):
            sx = x0 + rng.uniform(2, step_w - 2)
            sy = y0 + rng.uniform(4, step_h - 6)
            if rng.random() < 0.5:
                c = rng.choice([(220, 60, 60), (230, 230, 230), (60, 90, 200), (240, 200, 60)])
                d.point((sx, sy), fill=c)

    # Corner floodlight rigs: a pole, a fixture, and a soft downward light cone.
    GLOW = (140, 140, 110)
    FIXTURE = (255, 238, 180)
    for cx, inward in ((70, 1), (890, -1)):
        pole_top = HORIZON_Y - 260
        d.line([(cx, pole_top), (cx, HORIZON_Y - 40)], fill=(22, 24, 30), width=5)
        d.rectangle([cx - 16, pole_top - 10, cx + 16, pole_top + 6], fill=(30, 32, 38))
        d.ellipse([cx - 10, pole_top - 6, cx + 10, pole_top + 10], fill=FIXTURE)
        d.polygon([(cx - 12, pole_top + 6), (cx + 12, pole_top + 6),
                    (cx + inward * 150, HORIZON_Y - 20), (cx - inward * 10, HORIZON_Y - 20)], fill=GLOW)

    ground_strip(d, (60, 70, 60), (24, 22, 24))

    # Ring ropes in the foreground — three horizontal cords, red/white/red — drawn
    # last so the ground gradient beneath them doesn't paint over the top.
    ROPE_COLORS = [(200, 60, 60), (235, 235, 235), (200, 60, 60)]
    for i, color in enumerate(ROPE_COLORS):
        ry = HORIZON_Y + 8 + i * 6
        d.line([(0, ry), (W, ry)], fill=color, width=3)

    img.save(os.path.join(OUT_DIR, "arena_bg_stadium.png"))


def make_neon():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    sky_gradient(d, (10, 8, 28), (34, 16, 56), (70, 30, 70), 0.6)
    stars(d, 12, 50, int(HORIZON_Y * 0.45))

    # Tall skyline, denser and darker than the dusk version, with neon-lit windows.
    rng = random.Random(17)
    NEON = [(255, 60, 190), (60, 220, 255), (255, 220, 60), (140, 255, 120)]
    BUILDING = (14, 10, 24)
    x = -20
    while x < W + 20:
        bw = rng.randint(50, 100)
        bh = rng.randint(90, 220)
        by = HORIZON_Y - bh
        d.rectangle([x, by, x + bw, HORIZON_Y + 2], fill=BUILDING)
        wx = x + 6
        while wx < x + bw - 6:
            wy = by + 10
            while wy < HORIZON_Y - 10:
                if rng.random() < 0.3:
                    d.rectangle([wx, wy, wx + 4, wy + 7], fill=rng.choice(NEON))
                wy += 13
            wx += 10
        # Occasional vertical neon sign strip on the building face.
        if rng.random() < 0.35:
            sign_color = rng.choice(NEON)
            sx = x + rng.randint(4, max(5, bw - 10))
            d.rectangle([sx, by + 6, sx + 4, by + min(70, bh - 10)], fill=sign_color)
            d.rectangle([sx - 2, by + 4, sx + 6, by + 8], fill=sign_color)
        x += bw + rng.randint(6, 18)

    # Soft neon glow reflected on the horizon.
    d.rectangle([0, HORIZON_Y - 4, W, HORIZON_Y + 2], fill=(120, 60, 160))

    ground_strip(d, (70, 30, 70), (18, 14, 30))
    img.save(os.path.join(OUT_DIR, "arena_bg_neon.png"))


def main():
    make_dojo()
    make_stadium()
    make_neon()
    print("Wrote arena_bg_dojo.png, arena_bg_stadium.png, arena_bg_neon.png")


if __name__ == "__main__":
    main()
