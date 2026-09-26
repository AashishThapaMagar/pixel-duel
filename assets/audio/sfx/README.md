# Sound effects

The game is silent until recordings are added here. Save a sound with the
matching name (`.ogg`, `.wav` or `.mp3`), then open the project in the Godot
editor once so it is imported; it plays at the moment listed below.

`scripts/sfx.gd` also contains synthesised stand-ins for every sound. They
are switched off (`USE_GENERATED := false`) because they sounded too
artificial; set it to `true` to hear them.

| Name | Plays when |
|---|---|
| `hit_light` | A punch or light attack lands |
| `hit_heavy` | A kick or heavy attack lands |
| `block` | An attack is guarded |
| `whoosh` | A punch is thrown |
| `whoosh_heavy` | A kick is thrown |
| `ko` | A fighter is knocked out |
| `round` | "ROUND 1" / "FINAL ROUND" is called |
| `fight` | "FIGHT!" appears |
| `menu_move` | Moving through a menu or hovering a button |
| `menu_confirm` | Pressing a button or locking in |
| `menu_back` | Closing a page or going back |
| `wipe` | The slash transition into fighter select or a match |

Free CC0 packs that fit: Kenney.nl "Impact Sounds" and "Interface Sounds".
