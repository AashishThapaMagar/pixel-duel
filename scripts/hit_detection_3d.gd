extends Node3D
## Synchronous shape queries avoid an extra frame of Area3D overlap latency.
var fighters: Array = []
var shape := BoxShape3D.new()

func _ready() -> void:
	process_physics_priority = 50
	shape.size = Vector3(0.56, 0.41, 0.46)

func _physics_process(_delta: float) -> void:
	for fighter in fighters:
		var hitbox: Area2D = fighter.hitbox
		if not hitbox.active or not fighter.controls_enabled or fighter.combat_paused or fighter.hitstop_remaining > 0.0:
			continue
		var center: Vector3 = fighter.body.global_position + fighter.forward * absf(hitbox.position.x) / 64.0 + Vector3.UP * -hitbox.position.y / 64.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(Vector3.UP, atan2(-fighter.forward.z, fighter.forward.x)), center)
		query.collision_mask = 2
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for contact in get_world_3d().direct_space_state.intersect_shape(query):
			var victim: Node = contact.collider.get_meta("fighter")
			if victim == fighter or victim in hitbox._already_hit:
				continue
			hitbox._already_hit.append(victim)
			var continued: bool = victim.state == victim.State.HITSTUN and victim._combo_attacker == fighter
			var previous_health: int = victim.health
			if victim.take_hit(hitbox.damage, hitbox.knockback, 1, fighter, hitbox.attack_type):
				fighter._on_hit_landed(hitbox.attack_type, continued, previous_health - victim.health)
