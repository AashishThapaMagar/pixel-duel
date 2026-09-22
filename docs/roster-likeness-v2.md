# Playable roster likeness v2

The reference is `assets/concepts/fighters/roster-photo-likeness-v2.png`. Its left-to-right lineup maps to Bib, Abhi, Ish, Anug, Anant (Ananta), Sab (Ballas), and Sup (Supreme). Existing names, moves, collision volumes, and balance remain intact.

This is a stylized procedural 3D interpretation, not a photoreal reconstruction. Blue and mint streetwear, an open purple vest, red tactical gear and shades, a green goalkeeper costume and cap, a purple split coat and glasses, a broad navy grappler with glasses, and a gold/teal martial outfit distinguish the roster. Mesh embroidery, separate hair locks, facial hair, gloves, fuller trousers and arms, and boot accents give the models more readable game silhouettes.

`fighter_roster.gd` owns appearance overrides separately from combat tuning. `fighter_likeness.gd` attaches costume and face details to the playable rig used by both arena fighters and live roster portraits. Costume pivots follow the torso/head and use the combat clock for subtle cloth motion; pause and hit-stop freeze that motion. Switching characters replaces the costume subtree.

Validation:

```powershell
godot --headless --path . --fixed-fps 60 -s res://tests/arena_3d_test.gd
godot --headless --path . --fixed-fps 60 -s res://tests/arcade_menu_test.gd
godot --path . --fixed-fps 60 -s res://tests/likeness_v2_test.gd -- --capture
```

The last check exercises all seven selections, repeated costume replacement, strike attachment, pause and hit-stop, and writes `.godot/likeness-v2-lineup.png` with a graphics driver.
