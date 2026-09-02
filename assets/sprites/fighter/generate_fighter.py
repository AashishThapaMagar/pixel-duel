"""
Generates the Pixel Duel fighter spritesheet: one PNG per animation frame,
drawn as real low-res pixel art (native 44x64 canvas, nearest-neighbor
upscaled 2x to 88x128) then composited into a single contact sheet for
review. Not run automatically by the game — a one-time art generation
script. Re-run with `python generate_fighter.py` after editing poses below.

Art is drawn in grayscale (outline/shadow/base/highlight/glove) so Godot can
tint the whole sprite per-player via Node2D.modulate (blue for P1, red for
P2), exactly like before — one sheet, two fighters. Anatomy is a step up
from the first pass: a headband + face, distinct fists and shoes, a belt
line, and a soft contact shadow to ground the character on the floor.
"""
from PIL import Image, ImageDraw
import os

NATIVE_W, NATIVE_H = 76, 64   # extra width on the right gives punches/hooks room to reach without clipping
SCALE = 2
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

OUTLINE = (12, 12, 12, 255)
SHADOW = (110, 110, 110, 255)      # back limbs — dimmer, reads as "farther"
BASE = (190, 190, 190, 255)        # head/torso
HIGHLIGHT = (240, 240, 240, 255)   # front limbs — brighter, reads as "nearer"
GLOVE = (255, 255, 255, 255)       # fists/shoes — brightest, punctuates the silhouette
SHADOW_DARK = (70, 70, 70, 255)    # belt / back-limb extremities
GROUND_SHADOW = (10, 10, 10, 90)

# Rest-pose rectangles (x0, y0, x1, y1) in native pixels. "Front" = the side
# the character throws attacks with (+x — art is authored facing right;
# Godot mirrors the whole sprite via flip_h for the other fighter).
HEAD = (15, 0, 29, 14)
HEADBAND = (15, 3, 29, 6)
EYE = (23, 7, 26, 9)
MOUTH = (19, 11, 25, 12)
TORSO = (10, 15, 34, 40)
BELT = (10, 34, 34, 37)
ARM_BACK = (0, 16, 9, 38)
ARM_BACK_FIST = (0, 38, 9, 46)
ARM_FRONT = (35, 16, 44, 38)
ARM_FRONT_FIST = (34, 38, 44, 47)
LEG_BACK = (12, 41, 21, 58)
LEG_BACK_SHOE = (11, 58, 22, 64)
LEG_FRONT = (23, 41, 32, 58)
LEG_FRONT_SHOE = (22, 58, 33, 64)


def rect(draw, box, fill, outline=OUTLINE):
    x0, y0, x1, y1 = box
    draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill, outline=outline)


def shift(box, dx, dy):
    return (box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy)


def draw_frame(leg_back, leg_front, arm_back, arm_front, body_dx=0, body_dy=0,
               leg_back_shoe=None, leg_front_shoe=None, arm_back_fist=None, arm_front_fist=None):
    leg_back_shoe = leg_back_shoe or shift(LEG_BACK_SHOE, leg_back[0] - LEG_BACK[0], leg_back[3] - LEG_BACK[3])
    leg_front_shoe = leg_front_shoe or shift(LEG_FRONT_SHOE, leg_front[0] - LEG_FRONT[0], leg_front[3] - LEG_FRONT[3])
    arm_back_fist = arm_back_fist or shift(ARM_BACK_FIST, arm_back[0] - ARM_BACK[0], arm_back[3] - ARM_BACK[3])
    arm_front_fist = arm_front_fist or shift(ARM_FRONT_FIST, arm_front[0] - ARM_FRONT[0], arm_front[3] - ARM_FRONT[3])

    img = Image.new("RGBA", (NATIVE_W, NATIVE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Contact shadow first, at fixed floor level, so the body draws over it.
    d.ellipse([8, 60, 36, 64], fill=GROUND_SHADOW)

    # Draw order: back leg+shoe, back arm+fist, torso+belt, head+face, front leg+shoe, front arm+fist.
    rect(d, leg_back, SHADOW)
    rect(d, leg_back_shoe, SHADOW_DARK)
    rect(d, arm_back, SHADOW)
    rect(d, arm_back_fist, SHADOW_DARK)
    rect(d, shift(TORSO, body_dx, body_dy), BASE)
    rect(d, shift(BELT, body_dx, body_dy), SHADOW_DARK, outline=None)
    rect(d, shift(HEAD, body_dx, body_dy), BASE)
    rect(d, shift(HEADBAND, body_dx, body_dy), HIGHLIGHT, outline=None)
    ex0, ey0, ex1, ey1 = shift(EYE, body_dx, body_dy)
    d.rectangle([ex0, ey0, ex1 - 1, ey1 - 1], fill=OUTLINE)
    mx0, my0, mx1, my1 = shift(MOUTH, body_dx, body_dy)
    d.line([(mx0, my0), (mx1, my0)], fill=OUTLINE)
    rect(d, leg_front, HIGHLIGHT)
    rect(d, leg_front_shoe, GLOVE)
    rect(d, arm_front, HIGHLIGHT)
    rect(d, arm_front_fist, GLOVE)

    return img.resize((NATIVE_W * SCALE, NATIVE_H * SCALE), Image.NEAREST)


FRAMES = {
    # Idle: gentle four-beat bob, arms at rest.
    "idle_0": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK, arm_front=ARM_FRONT),
    "idle_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=shift(ARM_FRONT, 0, -1), body_dy=-1),
    "idle_2": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, 0, -1),
                   arm_front=shift(ARM_FRONT, 0, -1), body_dy=-2),
    "idle_3": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=shift(ARM_FRONT, 0, -1), body_dy=-1),

    # Walk cycle: legs cross-swing (horizontal only — the hip stays flush
    # with the torso so no gap opens up), arms counter-swing, slight bounce.
    "walk_0": dict(leg_back=shift(LEG_BACK, -4, 0), leg_front=shift(LEG_FRONT, 4, 0),
                   arm_back=shift(ARM_BACK, 3, -3), arm_front=shift(ARM_FRONT, -3, 3)),
    "walk_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=ARM_FRONT, body_dy=-1),
    "walk_2": dict(leg_back=shift(LEG_BACK, 4, 0), leg_front=shift(LEG_FRONT, -4, 0),
                   arm_back=shift(ARM_BACK, -3, 3), arm_front=shift(ARM_FRONT, 3, -3)),
    "walk_3": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=ARM_FRONT, body_dy=-1),

    # Jump: knees lift slightly (not into the torso), arms raise.
    "jump": dict(leg_back=(9, 38, 15, 54), leg_front=(14, 38, 20, 54),
                 arm_back=shift(ARM_BACK, 1, -10), arm_front=shift(ARM_FRONT, -1, -10),
                 body_dy=-3),

    # Jab: quick forward punch — windup, extend, recover.
    "punch_0": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, 1, 1),
                    arm_front=shift(ARM_FRONT, -4, 2), body_dx=-1),
    "punch_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, -1, -1),
                    arm_front=(38, 19, 62, 26), arm_front_fist=(56, 19, 68, 27), body_dx=2),
    "punch_2": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                    arm_front=shift(ARM_FRONT, -1, 1), body_dx=1),

    # Hook (Boxing's kick-button attack): wider, slower swing.
    "hook_0": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, 1, 2),
                   arm_front=shift(ARM_FRONT, -3, 7), body_dx=-1),
    "hook_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, -1, -2),
                   arm_front=(37, 12, 63, 20), arm_front_fist=(57, 11, 70, 21), body_dx=2),
    "hook_2": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=shift(ARM_FRONT, -1, 3), body_dx=1),

    # Kick: leg snaps up and forward, arms counter-balance, then settles.
    "kick_0": dict(leg_back=shift(LEG_BACK, -1, 0), leg_front=(16, 26, 38, 36),
                   leg_front_shoe=(34, 25, 46, 36),
                   arm_back=shift(ARM_BACK, -1, -1), arm_front=shift(ARM_FRONT, 1, 1),
                   body_dx=-1),
    "kick_1": dict(leg_back=shift(LEG_BACK, -1, 0), leg_front=(18, 32, 44, 41),
                   leg_front_shoe=(40, 31, 52, 42),
                   arm_back=shift(ARM_BACK, -2, -2), arm_front=shift(ARM_FRONT, 2, 2),
                   body_dx=-2, body_dy=1),
    "kick_2": dict(leg_back=LEG_BACK, leg_front=shift(LEG_FRONT, 1, 0),
                   arm_back=ARM_BACK, arm_front=shift(ARM_FRONT, 1, 0), body_dx=-1),

    # Block: guard raised, braced back slightly.
    "block": dict(leg_back=shift(LEG_BACK, 0, 0), leg_front=shift(LEG_FRONT, 1, 0),
                  arm_back=shift(ARM_BACK, 4, -8), arm_front=shift(ARM_FRONT, -3, -8),
                  body_dx=-1),

    # Hitstun: flinch back and away from the hit.
    "hitstun": dict(leg_back=shift(LEG_BACK, -1, 0), leg_front=shift(LEG_FRONT, 1, 0),
                    arm_back=shift(ARM_BACK, -3, -4), arm_front=shift(ARM_FRONT, 3, -4),
                    body_dx=-2, body_dy=-1),
}


def main():
    for name, pose in FRAMES.items():
        frame = draw_frame(**pose)
        frame.save(os.path.join(OUT_DIR, f"{name}.png"))

    # KO: drawn separately as a horizontal, flattened pose (wider canvas).
    W, H = NATIVE_W * SCALE, NATIVE_H * SCALE
    ko = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ko)
    y = H - 30
    d.ellipse([10, y + 14, W - 10, y + 24], fill=GROUND_SHADOW)
    rect(d, (10, y, 70, y + 22), SHADOW)          # sprawled legs
    rect(d, (72, y - 6, 118, y + 16), BASE)       # torso, lying down
    rect(d, (118, y - 14, 142, y + 4), BASE)      # head
    rect(d, (48, y - 16, 82, y + 2), HIGHLIGHT)   # flung-out arm
    rect(d, (44, y - 20, 58, y - 8), GLOVE)       # fist
    ko.save(os.path.join(OUT_DIR, "ko.png"))

    # Contact sheet for a quick visual sanity check.
    names = list(FRAMES.keys()) + ["ko"]
    cols = 6
    cell_w, cell_h = NATIVE_W * SCALE + 10, NATIVE_H * SCALE + 10
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (60, 60, 60, 255))
    for i, name in enumerate(names):
        frame = Image.open(os.path.join(OUT_DIR, f"{name}.png"))
        x = (i % cols) * cell_w + 5
        y2 = (i // cols) * cell_h + 5
        sheet.paste(frame, (x, y2), frame)
    sheet.save(os.path.join(OUT_DIR, "_contact_sheet.png"))
    print(f"Wrote {len(names)} frames + contact sheet to {OUT_DIR}")


if __name__ == "__main__":
    main()
