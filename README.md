# Pixel Duel

A local two-player 2D fighting game prototype built in **Godot 4.2+**. The fighters now use a continuously animated 2D joint rig with connected limbs, distinct guards, anticipation, contact poses, recovery, hit reactions, and a falling KO. Combat runs at 60 physics ticks per second.

This is a foundation for responsive fighting-game movement, not a finished AAA character or 3D animation system. Tekken-style 3D presentation would be a separate production step involving modeled and rigged characters and authored animation clips.

A match is **four rounds, each fought under a different fighting style** — Karate, then Muay Thai, then Boxing, then Freestyle MMA — applied to both fighters so every round is a genuinely different fight, not just a reskinned one. See "Fighting styles" below.

The smoke and combat regression suites exercise damage, real hitbox overlaps, startup/recovery, hit-stop, buffered input, dashes, jumping, style mechanics, and round reset in Godot 4.2.

## Controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Move | A / D | Left / Right arrows |
| Dash / backdash | Double-tap A / D | Double-tap Left / Right |
| Jump | W | Up arrow |
| Block | S (hold) | Down arrow (hold) |
| Punch (light) | F | K |
| Kick (heavy) | G | L |
| Restart after round ends | R | R |
| Back to main menu | Esc | Esc |

Pressing an attack shortly before recovery ends queues it for the first available frame (a 130 ms input buffer). A **landed light attack into heavy** can cancel its recovery after contact; a blocked or missed light must finish recovery. In Boxing, heavy throws a hook. A forward dash can be interrupted with an attack or guard; a backdash has no invulnerability.

## Main menu

The game boots into `scenes/MainMenu.tscn` (set as `run/main_scene` in project.godot) rather than straight into a fight:

- **Play** — starts a fresh match at `Arena.tscn` (round 1, Karate).
- **Settings** — Fullscreen toggle and a Volume slider, both backed by the `Settings` autoload (`scripts/settings.gd`), which applies them immediately (`DisplayServer`/`AudioServer`) and persists them to `user://settings.cfg` so they survive a restart. Volume controls the Master audio bus — there's no sound yet, but the plumbing is there for whenever sound effects are added.
- **Exit** — quits.

Both screens live in the one `MainMenu` scene (`MainScreen` / `SettingsScreen` Control nodes toggled visible by `main_menu.gd`) rather than separate scene files, since there's so little to each. Pressing Esc during a match returns to this menu at any time.

## Project layout

```
pixel-duel/
  project.godot        Engine/project settings + input map
  icon.svg              Project icon
  scenes/
    MainMenu.tscn        Entry point: Play / Settings / Exit
    Arena.tscn           A match: two fighters, ground, camera, UI
    Player.tscn          A single fighter (body, hit/hurt boxes, collision)
  scripts/
    main_menu.gd         Main menu screen-switching (Play/Settings/Exit)
    settings.gd           Autoload: fullscreen/volume, applied + saved to user://settings.cfg
    player.gd            Movement, attacks, blocking, health, state machine
    fighter_visual.gd    Articulated 2D fighter and combat-synchronized poses
    combat_effects.gd    Ground shadows, contact sparks, camera shake
    fight_style.gd        FightStyle resource: one fighting discipline's stats + mechanic flags
    hitbox.gd             Damage-dealing region, active only during attack frames
    hurtbox.gd             Damage-receiving region
    arena.gd              Round/match manager: styles per round, timer, health bars, win/KO/restart
  resources/
    styles/               karate.tres, muay_thai.tres, boxing.tres, mma.tres — one round each
  assets/
    sprites/fighter/       Fighter animation frames (PNG) + generate_fighter.py that drew them
    backgrounds/           arena_bg.png + generate_arena_bg.py that drew it
  tests/
    combat_test.gd        Movement, input, collision, and style regression suite
    smoke_test.gd         Optional headless test — not needed to play the game
```

## 1. Install the tools

1. **Godot 4.2+** — download from [godotengine.org/download](https://godotengine.org/download) (the standard, non-.NET build is fine — this project uses GDScript, not C#). No installer needed on most platforms; it's a single executable.
2. **VS Code** — [code.visualstudio.com](https://code.visualstudio.com) if you don't already have it.
3. In VS Code, install the **"Godot Tools"** extension (by `geequlim`) from the Extensions panel. This gives you GDScript syntax highlighting, autocomplete, and debugging.
4. In the Godot editor, go to **Editor > Editor Settings > Text Editor > External Editor**, enable "Use External Editor", and point it at your VS Code executable. Now double-clicking a script in Godot opens it in VS Code.

## 2. Run the game

- Open Godot, click **Import**, select the `project.godot` file in this folder, then open the project.
- Press **F5** (or the Play button) to run. `MainMenu.tscn` is the main scene; choose Play to enter the arena.
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

## Movement and combat flow

- Ground movement accelerates quickly and brakes firmly. Backward walking uses 72% of forward speed. Double-tap within 220 ms to dash.
- Jumps have a 50 ms anticipation pose, conserved horizontal launch momentum, limited air correction, and 50 ms of landing recovery. Stage bounds prevent walking off the arena.
- Grounded neutral and guard states face the opponent automatically. Attacks and jumps commit their facing until they finish.
- Every attack has **startup, active, and recovery** phases. Style resources expose startup and active durations plus total duration; at least 50 ms of recovery is enforced. The striking pose and hitbox use the same clock.
- Hitboxes deal damage once per opponent per swing, including when the opponent was already overlapping when contact began. Hits and parries immediately disable an interrupted fighter's outgoing hitbox.
- Normal hits push defenders away from the attacker. Guard has its own blockstun and reduced pushback. Only unblocked hits grant a hit confirm or count toward style chains.
- Light impacts freeze both fighters for 45 ms; kicks freeze them for 75 ms. Inputs remain buffered during the freeze, while combat clocks pause. Contact sparks and subtle camera shake distinguish hits from guard impacts.
- Round end locks combat while allowing the KO animation to settle. Restart clears buffered inputs, hit-stop, stale attacks, combo history, and animation state.

The controller lives in `scripts/player.gd`. The visual rig in `scripts/fighter_visual.gd` uses fixed-length two-bone limbs and blends neutral, locomotion, jump, and reaction poses. Attack poses sample the combat clock directly to avoid animation lag. `scripts/combat_effects.gd` draws ground shadows and contact sparks.

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

## Art and animation

`Player.tscn` uses the code-native 2D fighter rig in `scripts/fighter_visual.gd`. Skin, clothing, wraps, and style accents are colored separately. Karate, Boxing, Muay Thai, and MMA use different guard poses. The footwork cycle follows distance traveled, so walking into an obstacle does not keep the walk cycle running.

The original PNG fighter frames and their Pillow generator remain in `assets/sprites/fighter/` as legacy assets; they are no longer the default character visuals. The skyline backdrop still uses `assets/backgrounds/arena_bg.png`.

Further character work can replace the renderer with authored sprites or a skeletal character while retaining the combat timings. Full 3D characters, throws, crouching/high-low attacks, air attacks, audio, and online play are not implemented.

## Optional: automated test

`tests/smoke_test.gd` runs the match logic headlessly and checks damage/blocking/KO/restart without needing to click around manually. You'll never need this to just play or edit the game — it's here in case you want a quick sanity check after making changes:

```bash
godot --headless --path . -s res://tests/smoke_test.gd
```

(or `Godot_v4.2.2-stable_linux.x86_64 --headless ...` depending on how your download is named — this is a command-line/CI convenience, not something you run through the Godot editor UI.)

For the movement and combat regression suite:

```bash
godot --headless --path . -s res://tests/combat_test.gd
```

Both test scripts exit with a nonzero status on assertion failures.
