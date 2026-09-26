# Animated fighter models

Fighters can use a skinned, animated 3D model instead of the procedural rig.
`scripts/fighter_models.gd` lists which fighters have one; everyone else keeps
the procedural look, so characters can be swapped in one at a time.
`scripts/fighter_animated.gd` picks a clip from the fighter's combat state each
frame and lines attack clips up with the game's own hit timing, so combat and
balance don't change.

`test-kenney/` holds a CC0 test dummy (Kenney "Mini Characters") wired to Anug
but switched off (`"enabled": false`). Set it to `true` to see the pipeline.

## Adding a real fighter with Mixamo

1. Get the character model (AI image-to-3D from the concept sheet, MakeHuman,
   or a Mixamo character) as FBX or OBJ, in a T-pose or A-pose.
2. Upload it at [mixamo.com](https://www.mixamo.com) and let it auto-rig.
3. Download the character once: **FBX Binary, With Skin, 30 fps**.
4. Download each animation below with that character selected:
   **FBX Binary, Without Skin, 30 fps, keyframe reduction off**. Tick
   **In Place** wherever Mixamo offers it.
5. Save them as `assets/fighters/<fighter id>/`, e.g.

   ```
   assets/fighters/anug/anug.fbx
   assets/fighters/anug/idle.fbx
   assets/fighters/anug/jab.fbx
   ...
   ```

6. Open the project in the Godot editor once so the files import.
7. Add or edit the fighter's entry in `scripts/fighter_models.gd`:

   ```gdscript
   "anug": {
       "scene": "res://assets/fighters/anug/anug.fbx",
       "enabled": true,
       "height": 1.8,
       "yaw": PI / 2.0,
       "files": {
           "idle": "res://assets/fighters/anug/idle.fbx",
           "jab": "res://assets/fighters/anug/jab.fbx",
           # one line per downloaded file
       },
       "clips": {"idle": "idle", "jab": "jab"},  # logical -> file key
       "impact": {"jab": 0.4},                    # where the blow lands
   },
   ```

Animations are shared by name: every character Mixamo rigs has the same
skeleton, so one set of animation files works for all seven fighters.

## Animations to download

Mixamo search terms that give good matches (exact titles vary):

| File / clip | Mixamo search | Used for |
|---|---|---|
| `idle` | "boxing idle" / "fighting idle" | standing guard |
| `walk` | "boxing step forward" / "walk forward" (In Place) | walking in |
| `walk_back` | "step backward" (In Place) | backing off |
| `sidestep` | "side step" / "strafe" (In Place) | W / S sidesteps |
| `run` | "run" (In Place) | running |
| `jump` | "jump" | jumps |
| `block` | "center block" / "body block" | holding guard |
| `block_hit` | "block hit" | blocking a hit |
| `hit` | "head hit" / "hit reaction" | light hits |
| `hit_heavy` | "stomach hit" / "big hit" | heavy hits |
| `ko` | "knocked out" / "knocked down" | knockouts |
| `jab` | "lead jab" / "jab" | light punches |
| `punch_heavy` | "hook punch" / "cross punch" | hooks, crosses, overhands |
| `kick` | "front kick" / "mma kick" | kicks |
| `kick_spin` | "roundhouse kick" / "spin kick" | spinning kicks, finishers |
| `grapple` | "grab" / "throw" | throws |
| `taunt` | "taunt" | taunts |

Any clip you skip falls back to a close one (`walk_back` plays `walk`
reversed, `hit_heavy` uses `hit`, and so on), so start with `idle`, `walk`,
`jab`, `kick`, `hit` and `ko` and add the rest later.

Mixamo's licence allows using its characters and animations in your game;
it doesn't allow sharing the raw files on their own. The `.fbx` files are
therefore listed in `.gitignore` and stay on your machine; a copy of the
project without them falls back to the procedural fighter automatically.

All seven fighters use the Mixamo X Bot body, tinted in their colours and
scaled to their build, with shared clips from `assets/fighters/anug/`
(jab, cross, kicks, hits, KO, block, injured run) and their own style clips
from `assets/fighters/<id>/style/` (idle stance, walk, back-step, strafes,
run and signature moves). `scripts/fighter_models.gd` (`STYLES`) lists each
fighter's style clips and their measured impact timing:

| Fighter | Stance | Signature clips |
|---|---|---|
| Anug | keeper crouch | Goalkeeper Catch (blocked hits), Dodging (backdash) |
| Ish | Bouncing Fight Idle | Hook Punch, Uppercut |
| Ballas | Wrestling Idle | Headbutt, Grab and Slam (throws) |
| Bib | quick fighting idle | Jab, Fast Run, Dodging (backdash) |
| Abhi | relaxed showman idle | Haymaker, Taunt, Victory |
| Supreme | Capoeira Ginga | Roundhouse Kick, Flip Kick |
| Ananta | Kung Fu stance | Martial Arts Kick, Fireball (victory) |

Winners play their victory clip over a knocked-out rival. Kicks land as
heavy hits, so the victim plays the body-hit reaction; at 25% health or
less, walking and running forward switch to Injured Run.
