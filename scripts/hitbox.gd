extends Area2D
## Hitbox: the region of an attack that DEALS damage.
## The owning Player enables/disables this (via `set_active`) only during the
## "active frames" of an attack animation, then turns it off again.

@export var damage: int = 5
@export var knockback: float = 260.0

# Which Player node fired this hitbox (so we don't hit ourselves and so the
# victim knows which direction to get knocked back).
var owner_player: Node = null
# Tracks who's already been hit during the current active window, so a single
# swing can't multi-hit the same opponent every physics frame it overlaps.
var _already_hit: Array = []

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

func set_active(active: bool) -> void:
	monitoring = active
	if active:
		_already_hit.clear()

func _on_area_entered(area: Area2D) -> void:
	if not monitoring:
		return
	if area.get_parent() == owner_player:
		return
	if area in _already_hit:
		return
	var victim = area.get_parent()
	if victim and victim.has_method("take_hit"):
		_already_hit.append(area)
		var attacker_facing = 1
		if owner_player and "facing" in owner_player:
			attacker_facing = owner_player.facing
		victim.take_hit(damage, knockback, attacker_facing)
