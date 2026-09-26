extends "res://scripts/arena.gd"
## Canvas HUD and shared round rules around one real 3D world.
var world: Node3D
var camera_3d: Camera3D
var camera_target := Vector3(0, CAMERA_HEIGHT, 0)
var camera_distance := CAMERA_CLOSE
var camera_zoom_hold := 0.0
## Tekken/Street Fighter framing: a low, nearly level camera at chest height
## that keeps the fighters large, turns to stay square-on to their fighting
## line, and sweeps in from the side while the round is announced.
const CAMERA_BACK := Vector3(0, 0.07, 0.9975)
const CAMERA_HEIGHT := 1.05
const CAMERA_CLOSE := 4.9
const CAMERA_FOV := 38.0
var camera_yaw := 0.0
var impact_meshes: Array[Dictionary] = []
var shake_3d := 0.0
var nepal_stage: Node3D
## Arena every round uses when a versus mode picked one; -1 plays the journey.
var fixed_stage := -1

func _enter_tree() -> void:
	world = Node3D.new()
	world.name = "World3D"
	add_child(world)
	_build_stage()
	for i in 2:
		var fighter: Node = get_node("Player%d" % (i + 1))
		var body := CharacterBody3D.new()
		body.name = "Fighter%d" % (i + 1)
		body.collision_layer = 8
		body.collision_mask = 1
		body.floor_snap_length = 0.15
		body.safe_margin = 0.002
		world.add_child(body)
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.30
		capsule.height = 1.7
		collider.shape = capsule
		collider.position.y = 0.85
		body.add_child(collider)
		var hurt := Area3D.new()
		hurt.name = "Hurtbox3D"
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		hurt.set_meta("fighter", fighter)
		body.add_child(hurt)
		var hurt_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.66, 1.78, 0.56)
		hurt_shape.shape = box
		hurt_shape.position.y = 0.89
		hurt.add_child(hurt_shape)
		var pivot := Node3D.new()
		pivot.name = "Rig"
		pivot.scale = Vector3.ONE / 64.0
		body.add_child(pivot)
		fighter.body = body
		fighter.pivot = pivot
		fighter.spawn_position = Vector3(-1.3 if i == 0 else 1.3, 0.02, 0)
		body.position = fighter.spawn_position
		fighter.get_node("Visual").world_root = pivot

func _ready() -> void:
	player1.opponent = player2
	player2.opponent = player1
	player1.apply_character(MatchSetup.selected_fighters[0])
	player2.apply_character(MatchSetup.selected_fighters[1])
	$UI/P1Label.text = "P1 / " + player1.character_profile.name
	$UI/P2Label.text = "P2 / " + player2.character_profile.name + (" / AI" if MatchSetup.vs_ai else "")
	p1_start_pos = player1.position
	p2_start_pos = player2.position
	if MatchSetup.vs_ai:
		player2.ai_controlled = true
		ai_controller = preload("res://scripts/ai_controller_3d.gd").new()
		ai_controller.fighter = player2
		ai_controller.opponent = player1
		add_child(ai_controller)
	var hit_detection := preload("res://scripts/hit_detection_3d.gd").new()
	hit_detection.fighters = [player1, player2]
	world.add_child(hit_detection)
	# Round manager calls reset() on this shared effects interface.
	combat_effects = preload("res://scripts/combat_effects.gd").new()
	combat_effects.visible = false
	combat_effects.set_process(false)
	add_child(combat_effects)
	for fighter in [player1, player2]:
		fighter.impact.connect(func(_point: Vector2, blocked: bool, heavy: bool): _impact_3d(fighter, blocked, heavy))
	health_bar1.max_value = player1.max_health
	health_bar2.max_value = player2.max_health
	player1.health_changed.connect(func(h, _mh): health_bar1.value = h)
	player2.health_changed.connect(func(h, _mh): health_bar2.value = h)
	player1.ko.connect(func(): _end_round(2))
	player2.ko.connect(func(): _end_round(1))
	for fighter in [player1, player2]:
		fighter.ko.connect(func(): preload("res://scripts/sfx.gd").fire("ko"))
	_build_move_ui()
	add_child(preload("res://scripts/match_hud.gd").new())
	if Settings.touch_controls:
		add_child(preload("res://scripts/touch_controls_3d.gd").new())
	result_label.visible = false
	_update_pips()
	fixed_stage = _resolve_stage()
	_begin_round(0)

## The versus arena choice as a concrete arena index, or -1 for the journey.
func _resolve_stage() -> int:
	if MatchSetup.arcade or MatchSetup.stage_choice == MatchSetup.JOURNEY_STAGE:
		return -1
	if MatchSetup.stage_choice == MatchSetup.RANDOM_STAGE:
		return randi() % nepal_stage.ROUNDS.size()
	return clampi(MatchSetup.stage_choice, 0, nepal_stage.ROUNDS.size() - 1)

func _begin_round(index: int) -> void:
	var stage := index if fixed_stage < 0 else fixed_stage
	nepal_stage.show_round(stage)
	super._begin_round(index)
	# One short comment under the round call: where the fight is, plus the
	# arcade ladder position when there is one.
	var place: String = nepal_stage.ROUNDS[stage].name
	if MatchSetup.arcade:
		place += "   /   " + ("FINAL BOSS" if MatchSetup.is_final_boss() else "RIVAL %d OF %d" % [MatchSetup.arcade_index + 1, MatchSetup.arcade_opponents.size()])
	banner_tagline.text = place
	$UI/ControlsHint.text = "P1  A/D move  W/S sidestep  |  F punch  G kick  E guard     |     P2  Left/Right move  Up/Down sidestep  |  K punch  L kick  O guard\nH / J grapple   |   Space / Enter jump   |   F1 combos     |     Esc menu"
	guide_text.text = guide_text.text.replace("Down is S (P1) / Down arrow (P2).", "Hold E (P1) / O (P2) for the command's down input.")
	guide_text.text = "MOVEMENT: A/D or Left/Right approach and retreat. W/S or Up/Down make short sidesteps. Space / Enter jump. E / O guard.\nForward and back are relative to your opponent. Sidestep committed strikes to evade them.\n\n" + guide_text.text
	camera_target = Vector3(0, CAMERA_HEIGHT, 0)
	camera_distance = CAMERA_CLOSE
	camera_zoom_hold = 0.0
	camera_yaw = 0.0
	_update_fight_camera(0.0)
	shake_3d = 0
	for spark in impact_meshes:
		spark.mesh.queue_free()
	impact_meshes.clear()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player1) or player1.body == null:
		return
	if move_guide.visible:
		return
	_update_fight_camera(delta)
	shake_3d = move_toward(shake_3d, 0.0, delta * 0.65)
	camera_3d.h_offset = sin(Time.get_ticks_msec() * 0.11) * minf(shake_3d, 0.012) if MatchSetup.camera_shake else 0.0
	nepal_stage.animate(delta)
	for spark in impact_meshes:
		spark.age += delta
		spark.mesh.scale = Vector3.ONE * (0.05 + spark.age * 3.0)
		spark.mesh.material_override.albedo_color.a = maxf(0, 1.0 - spark.age / 0.22)
		if spark.age >= 0.22:
			spark.mesh.queue_free()
	impact_meshes = impact_meshes.filter(func(spark): return spark.age < 0.22)

func _update_fight_camera(delta: float) -> void:
	# Scene transitions can detach this arena before its last callback runs.
	if not is_inside_tree() or get_viewport() == null or not is_instance_valid(camera_3d):
		return
	var a: Vector3 = player1.body.position
	var b: Vector3 = player2.body.position
	var midpoint: Vector3 = (a + b) * 0.5
	# Tekken-style: stay square-on to the line between the fighters, so they
	# are always seen in profile and sidesteps turn the stage behind them
	# instead of swinging the view round to a front angle. Measured
	# left-to-right so the camera never flips when fighters cross over.
	var axis: Vector3 = preload("res://scripts/player_3d.gd").axis_between(a, b)
	var target_yaw := clampf(atan2(axis.z, axis.x), -1.05, 1.05)
	# Follow closely (a lagging camera is what shows the fighters' fronts),
	# ignoring only sub-degree jitter.
	if absf(angle_difference(camera_yaw, target_yaw)) > 0.01:
		camera_yaw = lerp_angle(camera_yaw, target_yaw, 1.0 - exp(-9.0 * delta))
	var turn := Basis(Vector3.UP, -camera_yaw)
	var back: Vector3 = turn * CAMERA_BACK
	var along: Vector3 = turn * Vector3.RIGHT
	var desired := camera_target
	var offset: Vector3 = midpoint - camera_target
	offset.y = 0.0
	var sideways := offset.dot(along)
	if absf(sideways) > 0.3:
		desired += along * (sideways - signf(sideways) * 0.3)
	var depth_offset := offset.dot(turn * Vector3.BACK)
	if absf(depth_offset) > 0.3:
		desired += (turn * Vector3.BACK) * (depth_offset - signf(depth_offset) * 0.3)
	# Jumps never pull the view up; the level horizon stays put.
	desired.y = CAMERA_HEIGHT
	camera_target = camera_target.lerp(desired, 1.0 - exp(-4.0 * delta))
	var size := get_viewport().get_visible_rect().size
	var tan_v := tan(deg_to_rad(camera_3d.fov) * 0.5)
	var tan_h := tan_v * size.x / maxf(size.y, 1.0)
	var screen_up: Vector3 = (turn * Vector3(0, CAMERA_BACK.z, -CAMERA_BACK.y))
	var required := CAMERA_CLOSE
	# Fit both standing silhouettes. Zoom out promptly as fighters separate and
	# ease back in once they close the gap again.
	for fighter in [player1, player2]:
		for height in [0.0, 2.1]:
			var point: Vector3 = fighter.body.position
			point.y = height
			var relative := point - camera_target
			var depth := relative.dot(back)
			var vertical := relative.dot(screen_up)
			required = maxf(required, depth + absf(relative.dot(along)) / (tan_h * 0.8))
			required = maxf(required, depth + absf(vertical) / (tan_v * (0.68 if vertical > 0.0 else 0.8)))
	if required > camera_distance:
		camera_zoom_hold = 0.6
		camera_distance = lerpf(camera_distance, required, 1.0 - exp(-6.0 * delta))
	else:
		camera_zoom_hold = maxf(0.0, camera_zoom_hold - delta)
		if camera_zoom_hold == 0.0 and camera_distance - required > 0.35:
			camera_distance = lerpf(camera_distance, required, 1.0 - exp(-1.4 * delta))
	var eye: Vector3 = camera_target + back * camera_distance
	# Round intro: swing in from a high three-quarter angle while the round
	# is announced, landing on the fight view as the banner clears.
	var intro := clampf(intro_timer / INTRO_TIME, 0.0, 1.0)
	if intro > 0.0:
		var ease_in := intro * intro * (3.0 - 2.0 * intro)
		var orbit := Basis(Vector3.UP, ease_in * 0.75)
		eye = camera_target + orbit * (back * camera_distance * (1.0 + 0.45 * ease_in)) + Vector3.UP * (0.9 * ease_in)
	camera_3d.fov = CAMERA_FOV
	camera_3d.position = eye
	camera_3d.look_at(camera_target)

func _impact_3d(fighter: Node, blocked: bool, heavy: bool) -> void:
	preload("res://scripts/sfx.gd").fire("block" if blocked else ("hit_heavy" if heavy else "hit_light"))
	var material := _material(Color("8bdeff") if blocked else Color("ffd78b"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mesh)
	mesh.position = fighter.body.position + fighter.forward * 0.25 + Vector3.UP * (1.03 if heavy else 1.37)
	mesh.scale = Vector3.ONE * 0.05
	impact_meshes.append({"mesh": mesh, "age": 0.0})
	shake_3d = 0.055 if heavy else 0.025

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _box_3d(label: String, size: Vector3, at: Vector3, color: Color, solid: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	world.add_child(node)
	node.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	node.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		node.add_child(collider)
	return node

func _build_stage() -> void:
	_box_3d("Platform", Vector3(14, 0.65, 10), Vector3(0, -0.325, 0), Color("685c4e"), true).get_child(0).hide()
	for edge in [-1, 1]:
		_box_3d("SideWall", Vector3(0.22, 5, 10.4), Vector3(edge * 4.66, 2.0, 0), Color.WHITE, true).get_child(0).hide()
		_box_3d("EndWall", Vector3(14.4, 5, 0.22), Vector3(0, 2.0, edge * 1.06), Color.WHITE, true).get_child(0).hide()
	nepal_stage = preload("res://scripts/nepal_stage_3d.gd").new()
	nepal_stage.name = "NepalJourney"
	world.add_child(nepal_stage)
	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.fov = CAMERA_FOV
	camera_3d.near = 0.1
	camera_3d.far = 400
	world.add_child(camera_3d)
	camera_3d.position = Vector3(0, 3.25, 10.2)
	camera_3d.look_at(Vector3(0, 0.8, 0))
	camera_3d.current = true
