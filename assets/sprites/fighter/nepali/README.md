Archived renderer documentation: live matches now use the [arcade sprites](../arcade/README.md). The descriptions below refer to the previous implementation.

# Nepali-inspired action fighters

Original illustrated sprite atlases for Who Won?, generated with the built-in image tool. Each PNG contains a 4 x 4 layout, with transparent space around the sprites. Full original atlases are preserved. JSON sidecars index actual silhouette bounds so extended kicks are not clipped at nominal cell boundaries. The game selects these regions using AtlasTexture.

| File | Silhouette and costume |
|---|---|
| anug.png | Medium athletic goalkeeper, green kit, cream gloves, woven trim |
| ish.png | Tall and skinny, red/black waistcoat, hand wraps, knee support |
| sab.png | Broad stocky heavyweight, navy wrap vest, patuka sash, cream trousers |
| bib.png | Short compact adult, blue streetwear, patterned sash, light shoes |
| abhi.png | Large heavyset adult, purple waistcoat, cream kurta, Dhaka topi |
| sup.png | Lean flexible dancer, gold wrap top, teal sash, loose trousers |
| anant.png | Tall powerful boss, dark daura-inspired wrap coat, gold trim |

Frame order (zero-based): 0 ready, 1 guard, 2–3 walking, 4 jump, 5–7 punch anticipation/contact/recovery, 8–10 kick anticipation/contact/recovery, 11 hit reaction, 12–14 signature anticipation/contact/recovery, 15 KO.

Locomotion now skins the original guard artwork using scripts/fighter_locomotion.gd. Per-character hip, knee and ankle landmarks animate a textured 2D mesh, preserving the original trousers, shoes, shading and outlines. The pelvis seam remains joined and footwear stays level during planted steps. The older walk_cycles.png and run_cycles.png assets are retained as source art but are no longer loaded for locomotion. Retreat keeps the fighter facing the opponent.

The sprites use authored body shapes and different display heights. Physics stays on the shared combat plane: visual size does not secretly change health, reach, or collision rules. The controller drives attack frames and freezes them during hit-stop. These are an initial 16-frame-per-fighter art pass; advanced moves share animation families where a dedicated clip is not yet authored.

`python tools/index_fighter_atlases.py` checks real alpha, exactly 16 silhouettes, and isolation from neighboring frames, then writes the JSON metadata. It reads the original artwork without modifying PNG pixels. The runtime renderer is `scripts/fighter_sprite_visual.gd`.
