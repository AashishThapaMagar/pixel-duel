# Pixel Duel

A 2D fighting game prototype — Street Fighter/Tekken style, but 2D — built in **Godot 4** so it's realistic to build solo. It's fully playable right now (movement, jump, punch, kick, block, chip damage, KO, round timer, restart) with placeholder colored-box "sprites" instead of art, so you can focus on getting the feel right before drawing/animating anything.

This has been test-run headlessly (imported and simulated in Godot 4.2.2) with no script or scene errors, and an automated smoke test (`tests/smoke_test.gd`) confirms damage, blocking, KO, and round-restart all work correctly.

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
    hitbox.gd             Damage-dealing region, active only during attack frames
    hurtbox.gd             Damage-receiving region
    arena.gd              Round timer, health bars, win/KO/restart logic
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

## Natural next steps

- Swap the colored-box placeholders for real sprites/animations (`AnimatedSprite2D` instead of `Polygon2D`).
- Add a proper combo system (attack inputs that chain within a timing window).
- Add sound effects and a hit-stop/screen-shake frame on impact for "juice."
- Add a character-select screen and a second/third character with different stats.
- Add a simple main menu scene before the arena.

## Optional: automated test

`tests/smoke_test.gd` runs the match logic headlessly and checks damage/blocking/KO/restart without needing to click around manually. You'll never need this to just play or edit the game — it's here in case you want a quick sanity check after making changes:

```bash
godot --headless --path . -s res://tests/smoke_test.gd
```

(or `Godot_v4.2.2-stable_linux.x86_64 --headless ...` depending on how your download is named — this is a command-line/CI convenience, not something you run through the Godot editor UI.)
