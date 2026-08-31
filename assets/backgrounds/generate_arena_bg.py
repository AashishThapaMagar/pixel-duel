"""
Generates the Pixel Duel arena backdrop: a 960x540 PNG (dusk sky gradient,
a distant mountain silhouette, a mid-layer city skyline, and a warm horizon
glow behind the fight) that sits behind the existing Ground/StaticBody2D in
Arena.tscn. One-time art generation script — re-run after editing below.
"""
from PIL import Image, ImageDraw
import os

W, H = 960, 540
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "arena_bg.png")

SKY_TOP = (24, 22, 48)
SKY_MID = (92, 58, 96)
SKY_HORIZON = (235, 150, 90)
MOUNTAIN = (48, 38, 66)
SKYLINE = (30, 26, 46)
WINDOW_LIT = (255, 214, 130)

HORIZON_Y = 420   # where the sky gradient meets the silhouettes (above the ground plane at y=450)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    # Sky: vertical gradient, top -> mid -> warm horizon glow.
    for y in range(HORIZON_Y):
        t = y / HORIZON_Y
        if t < 0.6:
            color = lerp(SKY_TOP, SKY_MID, t / 0.6)
        else:
            color = lerp(SKY_MID, SKY_HORIZON, (t - 0.6) / 0.4)
        d.line([(0, y), (W, y)], fill=color)
    d.rectangle([0, HORIZON_Y, W, H], fill=SKY_HORIZON)

    # A few soft stars in the upper sky.
    import random
    rng = random.Random(7)
    for _ in range(40):
        x = rng.randint(0, W - 1)
        y = rng.randint(0, int(HORIZON_Y * 0.5))
        b = rng.randint(150, 255)
        d.point((x, y), fill=(b, b, b))

    # Distant mountain range (soft, low-contrast silhouette).
    mtn_pts = [(0, HORIZON_Y)]
    rng2 = random.Random(3)
    x = 0
    while x < W:
        x += rng2.randint(60, 120)
        peak_y = HORIZON_Y - rng2.randint(40, 110)
        mtn_pts.append((min(x, W), peak_y))
    mtn_pts.append((W, HORIZON_Y))
    d.polygon(mtn_pts, fill=MOUNTAIN)

    # Nearer city skyline (flat-topped rectangular buildings, some lit windows).
    rng3 = random.Random(11)
    x = -20
    while x < W + 20:
        bw = rng3.randint(40, 90)
        bh = rng3.randint(60, 160)
        by = HORIZON_Y - bh
        d.rectangle([x, by, x + bw, HORIZON_Y + 2], fill=SKYLINE)
        # Windows.
        wx = x + 6
        while wx < x + bw - 6:
            wy = by + 8
            while wy < HORIZON_Y - 10:
                if rng3.random() < 0.35:
                    d.rectangle([wx, wy, wx + 4, wy + 6], fill=WINDOW_LIT)
                wy += 12
            wx += 10
        x += bw + rng3.randint(4, 16)

    # Ground-plane gradient strip just above where Arena's Ground node sits,
    # so the transition from backdrop to floor isn't a hard seam.
    for y in range(HORIZON_Y, H):
        t = (y - HORIZON_Y) / (H - HORIZON_Y)
        color = lerp(SKY_HORIZON, (40, 30, 40), t)
        d.line([(0, y), (W, y)], fill=color)

    img.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
