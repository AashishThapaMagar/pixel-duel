# Nepal arena models

The four GLBs in `models/` were supplied by the user from `WhoWon-Arenas`.
Their original geometry, transforms and embedded textures are preserved.
Godot extracts the embedded PNGs beside each GLB during import; retain those
files and their import settings with the models.

`scripts/nepal_stage_3d.gd` decodes source GLBs using `GLTFDocument` and caches
the resulting scenes in memory, shared by fighting and menu previews. This
avoids loading a Godot 4.5 binary import cache when playing with Godot 4.2.
Export builds must include `assets/arenas/models/*.glb` as original files
(use **Keep File** for these resources in the export preset).
If a model cannot load, procedural scenery supplies the complete arena.
The models use the existing game scale: the dais is 12.2 by
3.8 units and its top is at y=0. Visual meshes do not create physics bodies;
`arena_3d.gd` continues to own the fighting floor and boundaries.

Runtime polish adds weathered materials, a detailed stone dais, brass lane
inlays, cloud skies, distance haze, practical light flicker, cloth motion,
lantern sway and halos. Fill and rim lights keep fighters readable at night.
These effects target the existing Compatibility renderer.

Validation: `tests/nepal_journey_test.gd` checks the model mapping, lighting,
animated pivots, grounded fighters, and fixed/random/journey arena selection.
Run with `-- --capture` on a rendered Godot invocation for four screenshots.

Godot 4.7's glTF importer leaves vertex colours off, which drew the ridges
flat white; `_import_arena` turns them back on for any mesh that has them.
