# Who Won?

An original action fighting game prototype in Godot 4.7, with articulated 3D fighters and side-on movement and short sidesteps on a solid Nepal courtyard. Every match lasts **four rounds**. Each fighter keeps their own moves throughout; the most round wins takes the match.

Choose a mode with **Up/Down**, then press **Enter** for the arcade character-select screen. All seven fighters fit in the portrait grid, with large live 3D previews on either side. P1 uses A/D and F to select/confirm; P2 uses Left/Right and K. Enter starts the match once ready. Computer modes pre-confirm the CPU; Arcade and Story choose the first rival automatically. The title screen is an arcade-style menu: a slanted mode list (Arcade, Story, VS Battle, VS Computer) over the live 3D arena, with each mode showing a different arena mood, a splash card for the selected mode, top tabs for Fighters / Arenas / How to Play / Settings / Exit, and a crimson slash wipe into character select. Menus share `scripts/ui_kit.gd`: heavy italic display type, parallelogram panels and a Nepal crimson / gold palette.

## 3D arena

Start Game now opens `scenes/Arena3D.tscn`. All seven fighters use lit meshes in the same 3D world, with shadows, gravity, capsule collision against the floor and walls, and circular fighter pushboxes. A/D and Left/Right control the main approach/retreat movement. W/S and Up/Down give slower sidesteps within a narrow 1.3-metre-deep fighting strip.

**Camera.** The fight camera is framed like Tekken / Street Fighter: low and nearly level at chest height, close enough that fighters fill most of the screen, zooming out only as they separate. It turns to stay square-on to the line between the fighters when they sidestep, ignores small footwork and jumps so the view stays steady, and swings in from a high three-quarter angle while each round is announced.

**Arena.** The four arenas load the supplied textured GLB scenes from `assets/arenas/models/`. `scripts/nepal_stage_3d.gd` adds weathered surface shading, softer daylight, warm practical lanterns with subtle halos, fighter fill/rim lighting, layered cloud skies, distant haze and brass fighting-lane inlays. Imported flag pivots flutter and lanterns sway; the collision floor remains at y=0. These are real 3D environments, including in the live menu previews. A flagstone fighting dais sits in a brick Durbar Square lined with Newari houses (timber string courses, carved lattice windows, tiled roofs on struts), with Himalayan ridges on the horizon under a shader sky. Every match follows four rounds: **Heritage Square** (day, three-tier pagoda with guardian lions and stone shikhara temples), **Lantern Square** (night, strings of paper lanterns), **Terrace Overlook** (sunset, a chautari with a pipal tree above terraced hills), and **Moonlit Stupa** (final night, a white stupa with watching eyes and radiating prayer flags). Prayer flags flutter, butter lamps flicker, sky lanterns rise behind the stupa in the finale, and rounds fade through black.

**Look.** Every round is rendered through an ACES tonemap with its own exposure, bloom on flames, lanterns, lit windows and the sun, depth fog plus a thin ground mist on the night squares, and a full-screen finishing grade (`scripts/arena_grade.gdshader`): teal shadows and amber highlights on the lamp-lit squares, a warm sunset, a cold clean finale, each with a soft vignette. The sky shader draws a crescent moon with a halo, twinkling stars of varied colour and a faint Milky Way at night, and sun-lit cloud edges by day. Night rounds add a shadow-casting key light over the dais, so fighters cast crisp shadows even under moonlight, and a soft contact shadow sits under each fighter whatever the lighting. Photo-scanned walls darken where they meet the ground and under ledges (a stand-in for ambient occlusion, which the Compatibility renderer cannot compute), and the flagstone dais holds rain puddles that mirror the lanterns at night. The Himalaya is dimmed under moonlight instead of glowing like daytime snow. The LOW quality preset turns off bloom and the key-light shadow; the grade pass is a single full-screen read and stays on everywhere.

**Performance.** The sun renders a single shadow map over the fighting area rather than cascades (rigged fighters are the dearest thing to draw and every pass redraws them), the night key light casts shadows only on the HIGH shadow setting, and the rig's small trim (eyes, brows, wraps, buttons, anklets and the like) skips every shadow pass, which removes roughly a third of the shadow draws per fighter. Afterimages copy the rig's big pieces with shared meshes instead of building a merged mesh, so nothing is uploaded mid-fight. Roster busts on the select screen redraw on alternate frames. Physics interpolation is on for the fighter bodies, so movement stays smooth on 120 Hz and 144 Hz displays while combat keeps its 60 Hz tick; the camera, scenery, effects and the pose-driven rig parts are excluded because they already move every rendered frame. Select-screen portraits animate and redraw at 10 Hz (busts) and 30 Hz (showcases), so seven idle busts no longer skin seven rigged bodies every frame. **Auto-adjust** (Settings ▸ Graphics) watches the frame rate during fights and steps the preset down one notch when a fight averages under 30 FPS for three seconds, with a line on screen saying so; it never steps up or touches a CUSTOM setup. Phones and tablets start on LOW. If a fight still stutters, Settings ▸ Graphics offers MEDIUM (2048 shadow atlas, no key-light shadow) and LOW (no bloom or grade, no shadows, 75% render scale), and Fight Options can switch Hit Effects off. These fictional settings celebrate Nepal's architecture and landscape rather than recreate specific monuments. Arcade and Story always play the four-arena journey. In VS Battle and VS Computer, fighter select has an arena picker (◀ ▶ or Tab): All 4 Arenas, any single arena for every round, or Random.

Combat keeps the existing move tables, stamina, hit confirms, throws, guard breaks, AI, four-round matches, and story/arcade progression. Strikes query oriented 3D volumes, so depth separation matters. Models are procedural stylized rigs, with fixed-length limbs and poses driven by the combat state; they are not ragdolls or imported motion-capture characters. The rigs use smoother primitives (32-segment spheres, 18-segment limbs), matte cloth with a generated woven normal grain, skin with a small specular and a quiet rim light, and slightly glossy hair and leather.

**Hit effects.** A landed strike pops a white-hot core, a camera-facing shock ring and a burst of hot sparks that fall under gravity; a guarded strike throws cold blue chips instead. The struck fighter flashes white-hot for a few frames, the camera jolts on two axes and kicks its lens in on heavy hits, and the finishing grade adds a brief radial colour split and shock ring around the impact. Heavy hits, landings and dashes puff courtyard dust at the feet. Dashes and heavy attacks leave translucent afterimages in the player's colour (blue for P1, red for P2). A knockout flashes the screen and briefly drains its colour. Camera shake and the lens kick follow the Fight Options shake setting; every effect is visual only and none of it changes the move tables or timings.

### Rigged fighters in motion

Rigged fighters (Mixamo, Meshy, any dropped-in rig) blend into every attack from the pose they were in, over a few frames, instead of snapping to the clip's first frame; a rig with no jump clip tucks its knees on the way up and lands softly through a procedural layer, and a guarded hit leans the fighter back when the rig has no block-hit clip. The leg and spine bones are found by name and their bend direction is calibrated once on the actual skeleton, so any humanoid rig works. Walk and run clips play within a narrower speed band so legs never look frantic. Imported body materials are brought to a matte skin-and-cloth finish (no metallic sheen, a soft rim, anisotropic mipmaps). Select-screen and title portraits are stills: the fighter settles into the guard and is drawn once, so nothing idles or twitches on those screens.

## Dropping in a rigged model

A rigged character with its own animations (a Meshy auto-rig export, a Mixamo character downloaded with clips, any rigged glTF) can replace a fighter's procedural rig without any table entry: save it as `assets/fighters/<fighter id>/meshy_rig.glb` (or `rig.glb`, or `<fighter id>.glb`) and that fighter uses it, decoded straight from the file if the editor has not imported it yet. `scripts/fighter_animated.gd` matches the file's animation names to the game's clips by keyword (idle, walk, run, jump, block, hit, punch or jab, kick, death or knockout, victory, and so on; `match_clip` lists them), and anything unmatched falls back along the usual chain. Attack clips land on the game's own hit frames, so combat is unchanged. A model with no animations still needs the Mixamo clip set described in `assets/fighters/README.md`. `tests/dropped_model_test.gd` covers the detection and the name matching.

## Menus, records and options

The title screen keeps its slanted mode column and live arena, now with a gold light sweeping the title and a two-line ledger under the splash card: your last fight and your running record. A **RECORDS** entry opens the ledger: matches, wins, win rate, best streak, knockouts, perfect rounds, arcade clears and play time as stat tiles, wins per mode, a per-fighter column with your favourite in gold, and a reset. Records live in `user://records.cfg` (`scripts/records.gd`, the `Records` autoload) and are written by the arena at the end of every round and match.

**Settings** is a hub: fullscreen, master and sound-effect volume, touch controls, the graphics preset, then Fight Options, Controls, How to Play and Reset Defaults. **Fight Options** adds Hit Effects (sparks, dust, trails and flashes) and Input Display (training-style key chips low on each player's side of the screen) beside AI difficulty, round timer and camera shake. **Controls** lists every key for both players. **Graphics** adds a Bloom and Grade toggle for the post-processing pass. The pause menu carries the same sliders and toggles mid-fight.

Fighter select has a **?** button and the **R** key for a random pick: the portrait spins through the roster with a slowing tick, lands, and locks in. Each showcase shows that fighter's record. The arena picker names each arena's mood under its title. Every match opens on a **VS clash**: both names slam in from either side under a gold VS while the camera cranes down, then the round call follows. A round won without taking damage earns a **PERFECT!** under the winner callout, a knockout slams **K.O.** onto the screen ahead of it, and the end of a match opens a results card: the verdict, the score, and both fighters' rounds, damage dealt, best combo, knockouts and perfects side by side. The title screen shows your favourite fighter (or the last one picked) standing in a spotlight in the mode's colour, and the mode list carries arcade-style numbers.

Rendered review of these screens (title, each options page, the select spin, the clash, the round call and a perfect) is written to `.godot/ui-*.png` by:

```sh
godot --path . --fixed-fps 60 -s res://tests/ui_capture.gd
```

## Controls

For immediate hands-on play, click **PRACTICE [F2]** on the main menu. Your selected 3D fighter enters the courtyard with a passive dummy, unlimited time, and automatic reset after a knockout. **R** resets positions and health. Use **FIGHTERS** first to change your character.

Hold a direction to walk; hold **Shift + forward** (P2: **Ctrl**) to run. **Double-tap forward and keep the second tap held** to continue from a dash into a run. Release forward, reverse, guard, or attack to end the run. Retreating stays in a guarded walk; double-tap backward to backdash.

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
- **Arcade** fights the other regular roster members before **Ananta**, the final boss. Each rival is a four-round match. Win to advance; losses and draws retry the same rival. Defeating Ananta completes the run. Starting Arcade with Ananta also ends in an Ananta mirror match.
- **How to Play**, **Settings**, and **Exit** remain available. Fullscreen and volume settings persist between launches.

The AI uses movement/guard inputs and the same expiring attack buffer, stamina costs, hit confirms, startup and recovery as players. It reacts to visible attacks after a delay. Ananta decides more frequently, but has no immunity, automatic damage, or extra health.

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
    records.gd            Autoload: the player's fight record, saved to user://records.cfg
    input_display.gd      Training-style input history chips on the match HUD
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

1. **Godot 4.7** (4.7.2 or later) — download from [godotengine.org/download](https://godotengine.org/download) (the standard, non-.NET build is fine — this project uses GDScript, not C#). No installer needed on most platforms; it's a single executable.
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
- Light impacts freeze both fighters for 45 ms; kicks freeze them for 75 ms. Inputs remain buffered during the freeze, while combat clocks pause. Contact sparks, a shock ring and a two-axis camera jolt distinguish hits from guard impacts, which throw blue chips and barely move the camera.
- Round end locks combat while allowing the KO animation to settle. Restart clears buffered inputs, hit-stop, stale attacks, combo history, and animation state.

The controller lives in `scripts/player.gd`. The live sprite renderer in `scripts/fighter_sprite_visual.gd` selects full-body arcade poses. Attack poses sample the combat clock directly. `scripts/combat_effects.gd` draws ground shadows and contact sparks.

## Action roster

| Fighter | Identity | Tradeoff |
|---|---|---|
| Anug | Goalkeeper glove checks, diving clearance, low saves; larger timed-parry window | 65 stamina, slower recovery of stamina |
| Ish | Fast footwork and powerful punches | Low strikes hit his weak knee for 25% extra damage; weaker kicks |
| Ballas | Heavy fists and short-range clinch throws that beat guard | 65 stamina; expensive grabs and committed recovery |
| Bib | Fastest movement, 135 stamina, running kicks | Weak punches |
| Abhi | Heavy punches, 125 stamina, a talking taunt | More guard chip and stamina drain while blocking |
| Supreme | Sway stance, low spiral, cartwheel strike, spinning kick and retreat feint | Evasion requires spacing; no invulnerability |
| Ananta | Strong all-round final boss with punches, kicks and a throw | No specialist weakness; normal 100 HP, stamina costs and punishable recovery |

Light strikes cost 5 stamina, regular heavies 11, command enders 18, grabs 20, and dashes 7. Stamina regenerates after 0.65 seconds without spending while idle, walking or jumping. Guard consumes stamina on impact and breaks if it cannot pay, leaving 0.55 seconds of vulnerability. Health and stamina reset each round.

**Throw counterplay:** jump, interrupt the windup, stay beyond grabbing range, or tap Light + Heavy together within 0.16 seconds before contact. Throws cannot grab airborne opponents or chain into hitstun/blockstun.

**Abhi:** Back + Heavy performs Big Talk. Completing its 0.9-second vulnerable animation restores 24 stamina; interruption grants nothing. Five-second cooldown. The taunt uses on-screen text, not recorded voice.

**Supreme:** Back + Heavy retreats with Slip Away. It deals no damage and grants no invulnerability.

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

Validated with Godot 4.7.2 using the Compatibility renderer.

`arena_3d.gd` builds the world and reuses the existing round/HUD manager. `player_3d.gd` adapts shared `player.gd` combat rules to a `CharacterBody3D` at 64 combat units per metre. Its inherited 2D collision is disabled; `hit_detection_3d.gd` resolves actual 3D strike volumes. `fighter_visual_3d.gd` places articulated meshes directly under the fighter's world rig. `ai_controller_3d.gd` measures 3D separation while retaining the original AI decisions. The HUD remains a canvas overlay.

Nepal journey regression and four rendered previews:

```sh
godot --headless --path . --fixed-fps 60 -s res://tests/nepal_journey_test.gd
godot --path . --fixed-fps 60 -s res://tests/nepal_journey_test.gd -- --capture
```

Screenshots are written to `.godot/nepal-round-1.png` through `nepal-round-4.png`. `scripts/nepal_stage_3d.gd` owns the round scenery and lighting. The original painted arenas remain archived for the legacy 2D scene.

Rendered review of the graphics pass (all four rounds at rest, a landed kick with its impact effects, an afterimage and the knockout flash), written to `.godot/graphics-*.png`:

```sh
godot --path . --fixed-fps 60 -s res://tests/graphics_capture.gd
```

On a machine without a display, `xvfb-run` with Mesa's software renderer produces the same images (`--rendering-driver opengl3`), slowly.
