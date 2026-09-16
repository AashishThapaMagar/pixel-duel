# Arcade fighter sprites

Seven original Nepali fighters redrawn in a KOF XIII-inspired arcade sprite style using the built-in imagegen tool. Original character identities, costumes, roster statistics, and moves are retained. Each new sheet contains 24 complete poses; the old illustration/mesh assets remain in `../nepali/` for reference.

The exact generation and correction prompts are saved in `prompts.json`. Source PNGs are unmodified generated artwork. They use a solid magenta backdrop, removed by `scripts/arcade_sprite.gdshader` at rendering time. They are not transparent PNG files when opened outside the game.

| Row | Frames | Content |
|---|---|---|
| 1 | 0–5 | Six walking poses |
| 2 | 6–11 | Six running poses |
| 3 | 12–17 | Ready, guard, jump, punch startup/contact/recovery |
| 4 | 18–23 | Kick startup/contact/recovery, hit, signature, KO |

`tools/index_arcade_atlases.py` reads the images without changing their pixels and writes `scripts/arcade_sprite_regions.gd`. It finds all 24 silhouettes, allowing extended attacks past nominal cell boundaries. It also records safe shader exclusion rectangles for neighboring artwork, checking that these never remove the selected silhouette. It records torso pivots, planted foot positions, and flight offsets so jumps and running flight poses retain clearance above the ground.

The live `fighter_sprite_visual.gd` uses only a Sprite2D and AtlasTexture. It caches sheets, advances movement poses from distance on the combat clock, and changes atlas regions only when the pose changes. Walk/retreat and run use different drawings. Intermediate poses bridge the narrow/wide transitions. Stops and guard changes select their pose immediately. Attack startup/contact/recovery remain tied to combat timing and hit-stop.

The old procedural-body parent and guard-deformation mesh are no longer instantiated in live matches. Existing tests of the old solver are archival diagnostics, not evidence of the new artwork's quality. Advanced attacks still share pose families; this asset pass is not a unique animation for every move in the catalog.

Validation:

```text
python tools/index_arcade_atlases.py
godot --headless --path . -s res://tests/fighter_sprite_test.gd
godot --headless --path . -s res://tests/locomotion_test.gd
godot --path . --fixed-fps 60 -s res://tests/arcade_visual_test.gd -- --capture
godot --headless --path . -s res://tools/locomotion_benchmark.gd
```

The local CPU microbenchmark after integration averaged 0.024–0.028 ms per fighter for physics sync plus the now-empty render callback. The previous run averaged 1.5–3.1 ms. These are separate local headless runs, not GPU or end-to-end FPS measurements. The benchmark also measures the archived deformation sampler independently.
