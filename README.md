# Pixel Duel

A 2D fighting game prototype — Street Fighter/Tekken style, but 2D — built in **Godot 4** so it's realistic to build solo. It's fully playable right now (movement, jump, punch, kick, block, chip damage, KO, round timer, restart) with placeholder colored-box "sprites" instead of art, so you can focus on getting the feel right before drawing/animating anything.

A match is **four rounds, each fought under a different fighting style** — Karate, then Muay Thai, then Boxing, then Freestyle MMA — applied to both fighters so every round is a genuinely different fight, not just a reskinned one. See "Fighting styles" below.

This has been test-run headlessly (imported and simulated in Godot 4.2) with no script or scene errors, and an automated smoke test (`tests/smoke_test.gd`) confirms damage, blocking, KO, and round-restart all work correctly.

## Controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Move | A / D | Left / Right arrows |
| Jump | W | Up arrow |
| Block | S (hold) | Down arrow (hold) |
| Punch (light) | F | K |
| Kick (heavy) | G | L |
| Restart after round ends | R | R |

## Project layout

```
pixel-duel/
  project.godot        Engine/project settings + input map
  icon.svg              Project icon
  scenes/
    Arena.tscn           Main scene: two fighters, ground, camera, UI
    Player.tscn          A single fighter (body, hit/hurt boxes, collision)
  scripts/
    player.gd            Movement, attacks, blocking, health, state machine
    fight_style.gd        FightStyle resource: one fighting discipline's stats + mechanic flags
    hitbox.gd             Damage-dealing region, active only during attack frames
    hurtbox.gd             Damage-receiving region
    arena.gd              Round/match manager: styles per round, timer, health bars, win/KO/restart
  resources/
    styles/               karate.tres, muay_thai.tres, boxing.tres, mma.tres — one round each
  tests/
    smoke_test.gd         Optional headless test — not needed to play the game
```

## 1. Install the tools

1. **Godot 4.2+** — download from [godotengine.org/download](https://godotengine.org/download) (the standard, non-.NET build is fine — this project uses GDScript, not C#). No installer needed on most platforms; it's a single executable.
2. **VS Code** — [code.visualstudio.com](https://code.visualstudio.com) if you don't already have it.
3. In VS Code, install the **"Godot Tools"** extension (by `geequlim`) from the Extensions panel. This gives you GDScript syntax highlighting, autocomplete, and debugging.
4. In the Godot editor, go to **Editor > Editor Settings > Text Editor > External Editor**, enable "Use External Editor", and point it at your VS Code executable. Now double-clicking a script in Godot opens it in VS Code.

## 2. Run the game

- Open Godot, click **Import**, select the `project.godot` file in this folder, then open the project.
- Press **F5** (or the Play button) to run. `Arena.tscn` is already set as the main scene.
- Edit `.gd` scripts in VS Code; edit `.tscn` scenes (moving nodes, resizing collision shapes, tweaking the layout) in the Godot editor itself — that part isn't done from VS Code.

## 3. Put it on GitHub

From a terminal in this folder (VS Code's built-in terminal works fine):

```bash
git init
git add .
git commit -m "Initial 2D fighting game prototype"
```

Then on GitHub.com, create a new empty repository (don't initialize it with a README), and run the two commands it shows you, e.g.:

```bash
git remote add origin https://github.com/<your-username>/pixel-duel.git
git branch -M main
git push -u origin main
```

The included `.gitignore` already excludes Godot's local cache folder (`.godot/`) so you're not committing generated files.

## How the fighting mechanics work (for when you want to extend them)

- **State machine** in `player.gd`: `IDLE, WALK, JUMP, PUNCH, KICK, BLOCK, HITSTUN, KO`.
- **Facing** is automatic — each fighter always turns to face their opponent, like real fighting games, so you never have to think about "player 2 is mirrored."
- **Hitboxes** (the fist/foot that deals damage) only turn on for a short "active window" during an attack (`punch_active_time` / `kick_active_time`), then turn back off — this is what gives attacks a proper "whiff" if you swing too early or late, instead of an invisible damage aura around the character.
- **Blocking** checks whether the defender is holding block *and* actually facing the attacker; if so damage is reduced to a small "chip damage" percentage (`block_chip_multiplier`) instead of full damage.
- Tunable numbers (damage, speeds, timings, health) are all `@export` variables at the top of `player.gd`, so you can tweak game feel directly in the Godot Inspector without touching code.

## Fighting styles (rounds 1–4)

Each round, `Arena` pulls one `FightStyle` resource from `resources/styles/` and calls `apply_style()` on both fighters — it overwrites their movement/damage/timing numbers *and* flips on that style's one signature mechanic. Everything else in `player.gd` (state machine, hit detection, KO) stays the same; styles only change the numbers and a small, clearly-marked branch per mechanic.

| Round | Style | Feel | Signature mechanic |
|---|---|---|---|
| 1 | **Karate** (`karate.tres`) | Fast, precise, low damage | **Perfect block**: block within `perfect_block_window` (0.15s) of a hit landing and it's a full parry — zero chip damage, the attacker gets knocked into hitstun instead. Rewards blocking on reaction, not just holding it. |
| 2 | **Muay Thai** (`muay_thai.tres`) | Slower, heaviest damage/knockback | **Chip-through kicks**: kicks add `kick_chip_bonus` on top of normal chip damage even when blocked — "low kicks still hurt." Guard alone isn't enough against the legs. |
| 3 | **Boxing** (`boxing.tres`) | Fastest feet, punches only | **No kicks / combo bonus**: the kick button throws a **hook** (a heavier punch) instead of a leg attack, and consecutive landed hits within `combo_window` escalate in damage (`combo_damage_step` per stack, up to `combo_max_stacks`) — reward aggression and chaining. |
| 4 | **Freestyle MMA** (`mma.tres`) | Everything mixed, highest stakes | **Finisher**: land a punch, then land a kick within `finisher_window` (0.35s), and that kick becomes a finisher at `finisher_damage_mult`/`finisher_knockback_mult` (on a `finisher_cooldown`) — punches and kicks are meant to be mixed, not spammed alone. |

Whoever wins more of the four rounds wins the match (round wins shown as `●○○○`-style pips next to each health bar); a tie in rounds is a match draw. Each round opens with a ~2.2s style banner (name + tagline) during which both fighters are frozen (`Arena._begin_round` disables their `_physics_process`) so nobody gets a free hit in before the round officially starts.

**To add a 5th style** (or replace one): duplicate one of the `.tres` files in `resources/styles/`, tweak its numbers/flags in the Godot Inspector (or by hand — they're plain text), then add it to the `round_styles` array at the top of `arena.gd`. No new signature mechanic is required — a style with all the "signature mechanic" flags off (`perfect_block_window = 0`, `kick_chip_bonus = 0`, `kicks_disabled = false`, `combo_damage_step = 0`, `has_finisher = false`) just plays as a plain numbers-only style.

## Natural next steps

- Swap the colored-box placeholders for real sprites/animations (`AnimatedSprite2D` instead of `Polygon2D`) — ideally one sprite set per style, since Karate/Muay Thai/Boxing/MMA all *look* different in real life too.
- Add sound effects, hit-stop (a few frozen frames on impact), and screen shake for "juice" — especially on perfect blocks and finishers, which are currently readable only through the flash-color tween.
- Add a character-select screen and a second/third character with different base stats layered on top of the per-round style.
- Add a simple main menu scene before the arena, and a "how to fight this round" recap screen between rounds (the banner's tagline is a start, but a full move-list per style would help new players).

## Optional: automated test

`tests/smoke_test.gd` runs the match logic headlessly and checks damage/blocking/KO/restart without needing to click around manually. You'll never need this to just play or edit the game — it's here in case you want a quick sanity check after making changes:

```bash
godot --headless --path . -s res://tests/smoke_test.gd
```

(or `Godot_v4.2.2-stable_linux.x86_64 --headless ...` depending on how your download is named — this is a command-line/CI convenience, not something you run through the Godot editor UI.)
