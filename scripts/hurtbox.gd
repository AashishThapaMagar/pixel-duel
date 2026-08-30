extends Area2D
## Hurtbox: the region of a fighter that can BE hit.
## Pure data holder — the Hitbox script does the damage-detection work,
## this just needs to exist on the correct collision layer so hitboxes can find it.

# No logic needed here yet. Kept as its own script (rather than reusing Area2D
# directly) so it's easy to add per-body-part armor / invulnerability later,
# e.g. a "duck under high attacks" mechanic.
