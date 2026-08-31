"""
Generates the Pixel Duel fighter spritesheet: one PNG per animation frame,
drawn as real low-res pixel art (native 35x50 canvas, nearest-neighbor
upscaled 2x to 70x100) then composited into a single contact sheet for
review. Not run automatically by the game — a one-time art generation
script. Re-run with `python generate_fighter.py` after editing poses below.

Art is drawn in grayscale (outline/shadow/base/highlight) so Godot can tint
the whole sprite per-player via Node2D.modulate (blue for P1, red for P2),
exactly like the previous polygon rig did — one sheet, two fighters.
"""
from PIL import Image, ImageDraw
import os

NATIVE_W, NATIVE_H = 35, 50
SCALE = 2
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

OUTLINE = (15, 15, 15, 255)
HIGHLIGHT = (255, 255, 255, 255)   # front limbs — brighter, reads as "nearer"
BASE = (195, 195, 195, 255)        # head/torso
SHADOW = (120, 120, 120, 255)      # back limbs — dimmer, reads as "farther"

# Rest-pose rectangles (x0, y0, x1, y1) in native pixels. "Front" = the
# side the character throws attacks with (+x, since art is authored facing
# right; Godot mirrors the whole sprite via flip_h for the other fighter).
HEAD = (6, 0, 16, 10)
TORSO = (4, 11, 18, 31)
LEG_BACK = (5, 32, 10, 50)
LEG_FRONT = (12, 32, 17, 50)
ARM_BACK = (0, 12, 5, 28)
ARM_FRONT = (17, 12, 22, 28)
EYE = (12, 3, 13, 4)


def rect(draw, box, fill):
    x0, y0, x1, y1 = box
    draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill, outline=OUTLINE)


def shift(box, dx, dy):
    return (box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy)


def draw_frame(leg_back, leg_front, arm_back, arm_front, body_dx=0, body_dy=0):
    img = Image.new("RGBA", (NATIVE_W, NATIVE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Draw order: back leg, front leg, back arm, torso, head, front arm
    # (back arm tucks behind the torso, front arm draws on top of it).
    rect(d, leg_back, SHADOW)
    rect(d, leg_front, HIGHLIGHT)
    rect(d, arm_back, SHADOW)
    rect(d, shift(TORSO, body_dx, body_dy), BASE)
    rect(d, shift(HEAD, body_dx, body_dy), BASE)
    ex0, ey0, ex1, ey1 = shift(EYE, body_dx, body_dy)
    d.rectangle([ex0, ey0, ex1 - 1, ey1 - 1], fill=OUTLINE)
    rect(d, arm_front, HIGHLIGHT)
    return img.resize((NATIVE_W * SCALE, NATIVE_H * SCALE), Image.NEAREST)


FRAMES = {
    # Idle: gentle bob, arms at rest.
    "idle_0": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK, arm_front=ARM_FRONT),
    "idle_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=shift(ARM_FRONT, 0, -1), body_dy=-1),

    # Walk cycle: legs cross-swing, arms counter-swing, slight bounce.
    "walk_0": dict(leg_back=shift(LEG_BACK, -4, 3), leg_front=shift(LEG_FRONT, 4, -2),
                   arm_back=shift(ARM_BACK, 3, -3), arm_front=shift(ARM_FRONT, -3, 3)),
    "walk_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=ARM_FRONT, body_dy=-1),
    "walk_2": dict(leg_back=shift(LEG_BACK, 4, -2), leg_front=shift(LEG_FRONT, -4, 3),
                   arm_back=shift(ARM_BACK, -3, 3), arm_front=shift(ARM_FRONT, 3, -3)),
    "walk_3": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=ARM_BACK,
                   arm_front=ARM_FRONT, body_dy=-1),

    # Jump: knees lift slightly (not into the torso), arms raise.
    "jump": dict(leg_back=(7, 30, 12, 44), leg_front=(11, 30, 16, 44),
                 arm_back=shift(ARM_BACK, 1, -8), arm_front=shift(ARM_FRONT, -1, -8),
                 body_dy=-3),

    # Jab: quick forward punch, two beats (windup, extend).
    "punch_0": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, 1, 1),
                    arm_front=shift(ARM_FRONT, -3, 2), body_dx=-1),
    "punch_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, -1, -1),
                    arm_front=(20, 15, 32, 21), body_dx=2),

    # Hook (Boxing's kick-button attack): wider, slower swing.
    "hook_0": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, 1, 2),
                   arm_front=shift(ARM_FRONT, -2, 6), body_dx=-1),
    "hook_1": dict(leg_back=LEG_BACK, leg_front=LEG_FRONT, arm_back=shift(ARM_BACK, -1, -2),
                   arm_front=(19, 10, 33, 17), body_dx=2),

    # Kick: leg snaps up and forward, arms counter-balance.
    "kick_0": dict(leg_back=shift(LEG_BACK, -1, 0), leg_front=(13, 22, 30, 30),
                   arm_back=shift(ARM_BACK, -1, -1), arm_front=shift(ARM_FRONT, 1, 1),
                   body_dx=-1),
    "kick_1": dict(leg_back=shift(LEG_BACK, -1, 0), leg_front=(15, 26, 34, 33),
                   arm_back=shift(ARM_BACK, -2, -2), arm_front=shift(ARM_FRONT, 2, 2),
                   body_dx=-2, body_dy=1),

    # Block: guard raised, braced back slightly.
    "block": dict(leg_back=shift(LEG_BACK, 0, 0), leg_front=shift(LEG_FRONT, 1, 0),
                  arm_back=shift(ARM_BACK, 3, -6), arm_front=shift(ARM_FRONT, -2, -6),
                  body_dx=-1),

    # Hitstun: flinch back and away from the hit.
    "hitstun": dict(leg_back=shift(LEG_BACK, -1, 0), leg_front=shift(LEG_FRONT, 1, 0),
                    arm_back=shift(ARM_BACK, -2, -3), arm_front=shift(ARM_FRONT, 2, -3),
                    body_dx=-2, body_dy=-1),
}


def main():
    for name, pose in FRAMES.items():
        frame = draw_frame(**pose)
        frame.save(os.path.join(OUT_DIR, f"{name}.png"))

    # KO: drawn separately as a horizontal, flattened pose (wider canvas).
    ko = Image.new("RGBA", (NATIVE_W * SCALE, NATIVE_H * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(ko)
    y = 78
    rect(d, (4, y, 34, y + 12), SHADOW)     # sprawled legs
    rect(d, (36, y - 2, 58, y + 8), BASE)   # torso, lying down
    rect(d, (58, y - 6, 70, y + 2), BASE)   # head
    rect(d, (24, y - 8, 40, y + 2), HIGHLIGHT)  # flung-out arm
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
