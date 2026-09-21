# Who Won?

An original action fighting game prototype in Godot 4.2+, with articulated 3D fighters and side-on movement and short sidesteps on a solid Nepal courtyard. Every match lasts **four rounds**. Each fighter keeps their own moves throughout; the most round wins takes the match.

Choose **Match Setup > Fighters** to select Anug, Ish, Sab, Bib, Abhi, Sup, or Anant. Start Game uses your selected fighters. The home screen remains free of character previews.

## 3D arena

Start Game now opens `scenes/Arena3D.tscn`. All seven fighters use lit meshes in the same 3D world, with shadows, a following perspective camera, gravity, capsule collision against the floor and walls, and circular fighter pushboxes. A/D and Left/Right control the main approach/retreat movement. W/S and Up/Down give slower sidesteps within a narrow 1.3-metre-deep fighting strip; holding them cannot carry fighters into the distant scenery. Fighters start closer, with a fixed-depth camera and a solid, opaque floor under the playable strip. Every match follows a four-arena Nepal-inspired journey: Heritage Courtyard (day), Lantern Courtyard (night), Terrace Valley (day), and Moonlit Heritage (final night). The ARENA menu previews this fixed sequence using live 3D views. These fictional settings celebrate Nepal's landscapes and heritage rather than recreate specific monuments. The opening Heritage Courtyard uses a muted, late-1990s 3D arcade aesthetic: weathered Nepal brickwork, carved timber windows, tiled eaves and a distant pagoda. A generated background plate is paired with a real textured 3D stone floor and fighter shadows. Neutral daylight and softer stone textures match the enclosed courtyard. Later rounds retain their illustrated scenery, including the nighttime finale. The camera follows combat and pulls back when fighters separate. Artwork and prompts for the opening arena are in [assets/backgrounds/nepal_retro/](assets/backgrounds/nepal_retro/), generated with the built-in image_gen tool; the previous illustrated artwork remains available in `assets/backgrounds/nepal_illustrated/`.

Combat keeps the existing move tables, stamina, hit confirms, throws, guard breaks, AI, four-round matches, and story/arcade progression. Strikes query oriented 3D volumes, so depth separation matters. Models are procedural stylized rigs, with fixed-length limbs and poses driven by the combat state; they are not ragdolls or imported motion-capture characters.

## Controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Approach / retreat | A / D | Left / Right |
| Short sidestep | W / S | Up / Down |
| Run | Hold Shift | Hold Ctrl |
| Dash / backdash | Double-tap A / D | Double-tap Left / Right |
| Jump | Space | Enter |
| Block | E (hold) | O (hold) |
| Punch (light) | F | K |
| Kick (heavy) | G | L |
| Restart after round ends | R | R |
| Back to main menu | Esc | Esc |

Pressing an attack shortly before recovery ends queues it for the first available frame (a 130 ms input buffer). A **landed light attack into heavy** can cancel its recovery after contact; a blocked or missed light must finish recovery. A forward dash can be interrupted with an attack or guard; a backdash has no invulnerability.

## Character combos and grapples

Every fighter now has an original punch-chain finisher, a kick-led three-hit route, and a close-range grapple. Try **F F G** or **G F G** (P1), **K K L** or **L K L** (P2), tapping as each hit connects with directions released. Grapple with **H / J** or punch + kick together; the same input just before contact escapes a throw. Open **F1** for your selected character's routes and timing. See [character combos and research](docs/character-combos.md) for the roster table, sources, counterplay, and validation.

## Command moves and combat timing

Every fighter has six directional normals and two original motion-command enders. Forward/back always mean toward/away from the opponent. For P1 facing right:

- **Driving ender:** E, E+D, D+G (down, down-forward, forward + heavy).
- **Breaking ender:** E, E+A, A+G (down, down-back, back + heavy).
- Finish the three-direction motion within 0.4 seconds. Use movement toward/away from the opponent as they circle you; P2 uses O for guard and L for heavy. The guard button supplies the command input formerly called down.
- Land **F → F → quarter-circle forward + G** for the command combo. Each button needs a fresh press; holding an attack does not continue a string.

Only a confirmed jab or cross can cancel into a command ender. Cancels open after active frames and close six frames later. Misses and blocked hits must recover. Enders cannot cancel again and are vulnerable on block or whiff.

Attacks have individual hitstun and blockstun. Hitting startup gives **COUNTER HIT** (+20% damage and six extra stun frames); catching recovery displays **PUNISH**. Uninterrupted hits scale damage by 15 percentage points per hit, down to 40%; escaping hitstun resets scaling. The combo count tracks actual uninterrupted hits, including manually linked attacks.

Press **F1** for all commands, combos, startup/active/recovery timings, and estimated on-block advantage at 60 Hz. These are original mechanics and tuning for Who Won?, not copied franchise frame data.

## Main menu

- **Start Game** enters a four-round match using your saved-in-session setup.
- **Match Setup** selects 2 Players, vs AI, or Arcade, plus previews of the four-stage Nepal journey. **Fighters** opens compact name selectors and trait descriptions for both players.
- **Arcade** fights the other regular roster members before **Anant**, the final boss. Each rival is a four-round match. Win to advance; losses and draws retry the same rival. Defeating Anant completes the run. Starting Arcade with Anant also ends in an Anant mirror match.
- **How to Play**, **Settings**, and **Exit** remain available. Fullscreen and volume settings persist between launches.

The AI uses movement/guard inputs and the same expiring attack buffer, stamina costs, hit confirms, startup and recovery as players. It reacts to visible attacks after a delay. Anant decides more frequently, but has no immunity, automatic damage, or extra health.

### Legacy illustrated arenas

The following artwork and ambience describe `Arena.tscn`, retained for the 2D reference and regression tests. Live matches use the 3D courtyard described above.

Seven selectable Himalayan backdrops live in assets/backgrounds/himalayan/: **Himalayan Lake**, **Prayer Flag Pass**, **Lakeside Temple**, **Rhododendron Grove**, **Terrace Village**, **Moonlit Monastery**, and **Sunrise Summit**. Match Setup previews each scene and shows its position in the seven-arena collection. The illustrated terraces replace the visible legacy floor while keeping the same collision floor, fighter positions, and stage bounds. Original background assets remain on disk.

The artwork was generated with the built-in image_gen tool. Full prompts are in [docs/arena-art-prompts.md](docs/arena-art-prompts.md). Each texture is scaled to the 960 x 540 game canvas at runtime.

The match HUD includes mirrored health bars, delayed damage trails, low-health and low-timer colors, round-win markers, and next-round/rematch buttons. F1 opens a scrolling move guide and pauses combat; Esc closes it or returns to the menu.

Interface code lives in `scripts/main_menu.gd`, `character_select.gd`, `match_hud.gd`, `ui_kit.gd`, and `menu_backdrop.gd`. The layout uses the project's 960 × 540 canvas and scales with the game window.

### Match setup: mode and arena

`scripts/match_setup.gd` (the `MatchSetup` autoload) also holds `vs_ai: bool` and `selected_arena: int`, set from the main menu's Match Setup dialog and read by `arena.gd` when a match starts. See "Player vs AI" and "Arenas" above.

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
    main_menu.gd         Main menu screen-switching (Play/Match Setup/Settings/Exit)
    match_setup.gd         Autoload: selected fighters, selected_arena, vs_ai — survives scene changes
    settings.gd           Autoload: fullscreen/volume, applied + saved to user://settings.cfg
    player.gd            Movement, attacks, blocking, health, state machine
    ai_controller.gd      Player-vs-AI opponent: movement inputs and buffered attack decisions
    fighter_visual.gd    Articulated 2D fighter and combat-synchronized poses
    combat_effects.gd    Ground shadows, contact sparks, camera shake
    fight_style.gd        FightStyle resource: one fighting discipline's stats + mechanic flags
    arena_catalog.gd       Selectable arena backdrops: name, tagline, texture, ground tint
    hitbox.gd             Damage-dealing region, active only during attack frames
    hurtbox.gd             Damage-receiving region
    arena.gd              Round/match manager: four-round matches, timer, health bars, win/KO/restart
  resources/
    styles/               action.tres for live matches; archived discipline resources
  assets/
    sprites/fighter/       Fighter animation frames (PNG) + generate_fighter.py that drew them
    backgrounds/           arena_bg*.png + generate_arena_bg.py / generate_arenas.py that drew them
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

The controller lives in `scripts/player.gd`. The live sprite renderer in `scripts/fighter_sprite_visual.gd` selects full-body arcade poses. Attack poses sample the combat clock directly. `scripts/combat_effects.gd` draws ground shadows and contact sparks.

## Action roster

| Fighter | Identity | Tradeoff |
|---|---|---|
| Anug | Goalkeeper glove checks, diving clearance, low saves; larger timed-parry window | 65 stamina, slower recovery of stamina |
| Ish | Fast footwork and powerful punches | Low strikes hit his weak knee for 25% extra damage; weaker kicks |
| Sab | Heavy fists and short-range clinch throws that beat guard | 65 stamina; expensive grabs and committed recovery |
| Bib | Fastest movement, 135 stamina, running kicks | Weak punches |
| Abhi | Heavy punches, 125 stamina, a talking taunt | More guard chip and stamina drain while blocking |
| Sup | Sway stance, low spiral, cartwheel strike, spinning kick and retreat feint | Evasion requires spacing; no invulnerability |
| Anant | Strong all-round final boss with punches, kicks and a throw | No specialist weakness; normal 100 HP, stamina costs and punishable recovery |

Light strikes cost 5 stamina, regular heavies 11, command enders 18, grabs 20, and dashes 7. Stamina regenerates after 0.65 seconds without spending while idle, walking or jumping. Guard consumes stamina on impact and breaks if it cannot pay, leaving 0.55 seconds of vulnerability. Health and stamina reset each round.

**Throw counterplay:** jump, interrupt the windup, stay beyond grabbing range, or tap Light + Heavy together within 0.16 seconds before contact. Throws cannot grab airborne opponents or chain into hitstun/blockstun.

**Abhi:** Back + Heavy performs Big Talk. Completing its 0.9-second vulnerable animation restores 24 stamina; interruption grants nothing. Five-second cooldown. The taunt uses on-screen text, not recorded voice.

**Sup:** Back + Heavy retreats with Slip Away. It deals no damage and grants no invulnerability.

Character stats live in `scripts/fighter_roster.gd`, attacks in `scripts/action_moves.gd`, and shared action rules in `resources/styles/action.tres`. Older discipline resources remain on disk for legacy regression tests, but are not used in normal matches.

## Art and animation

`Player.tscn` uses the arcade sprite renderer in `scripts/fighter_sprite_visual.gd`. Each fighter has a distinct atlas. The footwork cycle follows distance traveled, so walking into an obstacle does not keep the walk cycle running.

The original PNG fighter frames and their Pillow generator remain in `assets/sprites/fighter/` as legacy assets; they are no longer the default character visuals. The preserved legacy skyline backdrop uses `assets/backgrounds/arena_bg.png`.

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

To validate menu dialogs, direct match entry, button contrast, health display, round progression, and rematches:

```bash
godot --headless --path . -s res://tests/ui_flow_test.gd
```

For rendered UI screenshots, omit `--headless` and append `-- --capture`; images are saved under `.godot/`.

The combat input regression suite also verifies mirrored motions, a live three-hit command combo against held guard, counter hits, recovery punishes, damage scaling, and round resets:

```bash
godot --headless --path . -s res://tests/fighting_system_test.gd
```

## Story mode later

Story mode layers dialogue around the arcade matchup order and enters the same 3D match scene.


Seven-arena selection and render check:

godot --path . -s res://tests/arena_gallery_test.gd -- --capture

This validates all seven textures, selector wraparound, Match Setup fight launch, and unchanged floor collision; screenshots are written to .godot/arena-01.png through arena-07.png.

All seven arenas include animated birds, drifting cloud wisps, and small backpackers following distant walking routes. Lake stages feature a rowing boat, the grove has windblown petals, and the high-altitude stages have light drifting snow. Scenery stays behind the fighters, pauses with the move guide, and continues across rounds without affecting combat physics. The arena gallery check also verifies animation, drawing order, and pause behavior.

Action roster, actual hitbox contact, stamina, special abilities, selection and arcade progression:

godot --headless --path . -s res://tests/action_roster_test.gd

Omit --headless and append -- --capture to save roster and signature-pose screenshots under .godot/action-*.png.

## Archived Nepali-inspired fighter sprites

This section describes the previous sprite renderer. Live 3D matches use `fighter_visual_3d.gd`.

The home screen now exposes Story, Arcade, Versus AI and Local Versus as selectable mode cards. Fighters, Arena/Setup, Fight Options, Move Guide and Settings have direct shortcuts. Fight Options sets AI difficulty (reaction and decision speed), a 60/99/120-second timer, and impact camera shake; matches retain four rounds.

Normal movement walks at 65% of movement speed. Hold Shift (P1), Ctrl (P2), or touch RUN while moving forward to run. Backward movement stays opponent-facing at 72% of walking speed; holding back guards grounded strikes, but throws beat guard. Complete arcade sprites replace the old guard-image deformation. Six walk drawings and six run drawings play from actual distance traveled, with intermediate poses bridging the cycle. Input changes select movement, guard, or idle immediately; rendering does not run a second animation clock. Run tests/locomotion_test.gd for roster playback, clock consistency, retreat guard and held run.

The playable fighters use seven KOF XIII-inspired arcade PNG atlases in `assets/sprites/fighter/arcade/`, rendered by `scripts/fighter_sprite_visual.gd`. Sab and Abhi are large, Ish is skinny, Bib is small, and Anug, Sup and Anant retain distinct original Nepali-inspired outfits. Each fighter has 24 full-body poses for walking, running, guard, jump, attacks, signature action, hit reaction and KO. Advanced moves still share animation families.

The original PNG pixels are preserved. Silhouette-derived frame regions and shader exclusions isolate extended limbs from neighboring poses, and grounded frames align to the fighting floor. Attack frames follow the combat clock and hit-stop. Character display height varies; collision and gameplay traits remain controlled by the combat system. The previous mesh renderer remains available on disk.

Asset validation: `python tools/index_arcade_atlases.py` (Pillow, numpy and scipy; reads artwork without modifying it). Runtime checks: `godot --headless --path . -s res://tests/fighter_sprite_test.gd`. See `assets/sprites/fighter/arcade/README.md` for frame mapping, prompts and benchmarks. The older `nepali/` atlases and mesh experiments are retained as reference assets.

## 3D verification and architecture

```sh
godot --headless --path . --fixed-fps 60 -s res://tests/arena_3d_test.gd
godot --path . --fixed-fps 60 -s res://tests/arena_3d_test.gd -- --capture
```

The integration test covers depth movement, diagonal speed, jumping/landing, walls, pushboxes, 3D hits and misses, guard, pause, AI depth tracking, roster changes and round resets. The rendered check writes `.godot/arena-3d-review.png`.

Validated with Godot 4.5.1 using the Compatibility renderer.

`arena_3d.gd` builds the world and reuses the existing round/HUD manager. `player_3d.gd` adapts shared `player.gd` combat rules to a `CharacterBody3D` at 64 combat units per metre. Its inherited 2D collision is disabled; `hit_detection_3d.gd` resolves actual 3D strike volumes. `fighter_visual_3d.gd` places articulated meshes directly under the fighter's world rig. `ai_controller_3d.gd` measures 3D separation while retaining the original AI decisions. The HUD remains a canvas overlay.

Nepal journey regression and four rendered previews:

```sh
godot --headless --path . --fixed-fps 60 -s res://tests/nepal_journey_test.gd
godot --path . --fixed-fps 60 -s res://tests/nepal_journey_test.gd -- --capture
```

Screenshots are written to `.godot/nepal-round-1.png` through `nepal-round-4.png`. `scripts/nepal_stage_3d.gd` owns the round scenery and lighting. The original painted arenas remain archived for the legacy 2D scene.
