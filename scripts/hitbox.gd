extends Area2D
## Logical activation avoids changing physics monitoring during collision callbacks.
@export var damage: int = 5
@export var knockback: float = 260.0
@export var attack_type: String = "punch"
var owner_player: Node = null
var active: bool = false
var _already_hit: Array = []

func _ready() -> void:
	monitoring = true
	area_entered.connect(_on_area_entered)

func set_active(value: bool) -> void:
	# Reset once at contact's leading edge, never on every active physics tick.
	if value and not active:
		_already_hit.clear()
	active = value

func _physics_process(_delta: float) -> void:
	# area_entered alone misses a defender who overlaps during the windup.
	if active and owner_player != null and not owner_player.combat_paused and owner_player.hitstop_remaining <= 0.0:
		for area in get_overlapping_areas():
			_on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if not active or owner_player == null or not owner_player.controls_enabled or owner_player.combat_paused:
		return
	if area.get_parent() == owner_player or area in _already_hit:
		return
	var victim := area.get_parent()
	if victim != null and victim.has_method("take_hit"):
		_already_hit.append(area)
		var continued: bool = victim.state == victim.State.HITSTUN and victim.stun_timer > 0.0
		var previous_health: int = victim.health
		var landed: bool = victim.take_hit(damage, knockback, owner_player.facing, owner_player, attack_type)
		if landed:
			owner_player._on_hit_landed(attack_type, continued, previous_health - victim.health)
