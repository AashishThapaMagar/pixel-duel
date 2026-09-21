extends "res://scripts/arena.gd"
## Canvas HUD and shared round rules around one real 3D world.
var world: Node3D
var camera_3d: Camera3D
var camera_target := Vector3(0, 0.8, 0)
var impact_meshes: Array[Dictionary] = []
var shake_3d := 0.0
var nepal_stage: Node3D

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
		fighter.spawn_position = Vector3(-2.2 if i == 0 else 2.2, 0.02, 0)
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
	_build_move_ui()
	add_child(preload("res://scripts/match_hud.gd").new())
	if Settings.touch_controls:
		add_child(preload("res://scripts/touch_controls_3d.gd").new())
	result_label.visible = false
	_update_pips()
	_begin_round(0)

func _begin_round(index: int) -> void:
	nepal_stage.show_round(index)
	super._begin_round(index)
	banner_round.text = "ROUND %d / %s" % [index + 1, nepal_stage.ROUNDS[index].name]
	banner_tagline.text = nepal_stage.ROUNDS[index].detail
	$UI/ControlsHint.text = "P1  WASD move / Space jump / E guard / F G attack     |     P2  Arrows move / Enter jump / O guard / K L attack\nSHIFT / CTRL run    /    DOUBLE-TAP A D dash    /    F1 MOVES    /    ESC MENU"
	guide_text.text = guide_text.text.replace("Down is S (P1) / Down arrow (P2).", "Hold E (P1) / O (P2) for the command's down input.")
	guide_text.text = "3D MOVEMENT: WASD / arrows move across the floor. Space / Enter jump. E / O guard.\nForward and back are relative to your opponent. Sidestep committed strikes to evade them.\n\n" + guide_text.text
	shake_3d = 0
	for spark in impact_meshes:
		spark.mesh.queue_free()
	impact_meshes.clear()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player1) or player1.body == null:
		return
	var midpoint: Vector3 = (player1.body.position + player2.body.position) * 0.5
	var distance: float = player1.body.position.distance_to(player2.body.position)
	camera_target = camera_target.lerp(midpoint + Vector3.UP * 0.85, 1.0 - exp(-5.0 * delta))
	# Fixed compass direction makes WASD stable even when rivals circle.
	var boom := Vector3(0, 2.4, 10.2) * clampf(0.76 + distance * 0.075, 0.88, 1.95)
	# Bring close combat forward while retaining wide framing at arena edges.
	boom *= lerpf(0.84, 1.0, smoothstep(3.0, 9.0, distance))
	camera_3d.position = camera_3d.position.lerp(camera_target + boom, 1.0 - exp(-5.0 * delta))
	camera_3d.look_at(camera_target)
	shake_3d = move_toward(shake_3d, 0.0, delta * 0.65)
	camera_3d.h_offset = sin(Time.get_ticks_msec() * 0.11) * shake_3d if MatchSetup.camera_shake else 0.0
	if move_guide.visible:
		return
	nepal_stage.animate(delta)
	for spark in impact_meshes:
		spark.age += delta
		spark.mesh.scale = Vector3.ONE * (0.05 + spark.age * 3.0)
		spark.mesh.material_override.albedo_color.a = maxf(0, 1.0 - spark.age / 0.22)
		if spark.age >= 0.22:
			spark.mesh.queue_free()
	impact_meshes = impact_meshes.filter(func(spark): return spark.age < 0.22)

func _impact_3d(fighter: Node, blocked: bool, heavy: bool) -> void:
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
		_box_3d("SideWall", Vector3(0.22, 5, 10.4), Vector3(edge * 7.1, 2.0, 0), Color.WHITE, true).get_child(0).hide()
		_box_3d("EndWall", Vector3(14.4, 5, 0.22), Vector3(0, 2.0, edge * 5.1), Color.WHITE, true).get_child(0).hide()
	nepal_stage = preload("res://scripts/nepal_stage_3d.gd").new()
	nepal_stage.name = "NepalJourney"
	world.add_child(nepal_stage)
	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.fov = 48
	camera_3d.near = 0.1
	camera_3d.far = 200
	world.add_child(camera_3d)
	camera_3d.position = Vector3(0, 3.25, 10.2)
	camera_3d.look_at(Vector3(0, 0.8, 0))
	camera_3d.current = true
