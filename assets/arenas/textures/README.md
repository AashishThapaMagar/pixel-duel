# Photo-scanned arena textures

All textures are from [Poly Haven](https://polyhaven.com) and are CC0 (public
domain, no attribution required). Each folder holds the 1K colour
(`_diff`), OpenGL normal (`_nor_gl`, imported as a normal map) and
roughness (`_rough`) maps.

| Folder | Used for | Real size of one repeat |
|---|---|---|
| `red_bricks_04` | House walls and brick plinths | 2.5 m |
| `red_brick` | Plaza paving | 1.4 m |
| `roof_09` | Tiled roofs | 4.0 m (shown at 3.2 m) |
| `weathered_brown_planks` | Timber frames, struts, poles | 1.8 m |
| `painted_plaster_wall` | Plastered houses | 2.0 m |
| `medieval_blocks_03` | Temple stone, steps, lions | 2.0 m |
| `white_plaster_02` | The whitewashed stupa | 1.0 m (shown at 1.5 m) |

`scripts/nepal_stage_3d.gd` recognises each baked pattern texture in the
arena GLBs by its average colour and swaps in the matching photo surface
(`PHOTO_TEXTURES`); `scripts/arena_photo_surface.gdshader` projects it in
world space at real scale. The carved lattice and gilt roofs keep their
original textures. To try a different scan, download its 1K JPGs into a new
folder and point the matching `PHOTO_TEXTURES` entry at it.
